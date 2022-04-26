# typed: false
# frozen_string_literal: true

require "eventmachine"
require "securerandom"
require "kcl/heartbeater"
require "kcl/stats"

module Kcl
  class Worker
    attr_reader :id, :liveness_timeout

    def self.run(id, record_processor_factory)
      worker = new(id, record_processor_factory)
      worker.start
    end

    def initialize(id, record_processor_factory)
      @id = id
      @record_processor_factory = record_processor_factory
      @live_shards = {} # Map<String, Boolean>
      @shards = {} # Map<String, Kcl::Workers::ShardInfo>
      @consumers = {} # [Array<Thread>] args the arguments passed from input. This array will be modified.
      @kinesis = nil # Kcl::Proxies::KinesisProxy
      @checkpointer = nil # Kcl::Checkpointer
      @heartbeater = nil
      @timer = nil
      @liveness_timeout = nil
      @live_workers = {}
      @workers = {}
    end

    # process 1                               process 2
    # kinesis.shards sync periodically
    # shards.start
    # go through shards, assign itself
    # on finish shard, release shard
    #
    # kinesis.shards sync periodically in parallel thread
    #

    # consumer should not block main thread
    # available_lease_shard? should divide all possible shards by worker ids

    # Start consuming data from the stream,
    # and pass it to the application record processors.
    def start
      Kcl.logger.info(message: "Start worker", object_id: object_id)

      demonize do
        Thread.current[:uuid] = @id
        heartbeat!
        sync_shards!
        sync_workers!
        rebalance_shards!
        cleanup_dead_consumers
        consume_shards!
      end

      cleanup

      Kcl.logger.info(message: "Finish worker", object_id: object_id)
    rescue StandardError => e
      Kcl.logger.error(e)
      raise e
    end

    def demonize(&block)
      return yield if ENV["DEBUG"] == "true"

      EM.run do
        trap_signals

        @timer = EM::PeriodicTimer.new(Kcl.config.sync_interval_seconds, &block)
      end
    end

    def heartbeat!
      @liveness_timeout = heartbeater.ping(self)
    end

    # Shutdown gracefully
    def shutdown(signal = :NONE)
      terminate_timer!
      terminate_consumers!

      EM.stop

      Kcl.logger.info(message: "Shutdown worker with signal #{signal} at #{object_id}")
    rescue StandardError => e
      Kcl.logger.error(e)
      raise e
    end

    # Cleanup resources
    def cleanup
      @live_shards = {}
      @shards = {}
      @live_workers = {}
      @workers = {}
      @kinesis = nil
      @checkpointer = nil
      @consumers = {}
      @heartbeater.cleanup(self)
    end

    def terminate_consumers!
      Kcl.logger.info(message: "Stop #{@consumers.count} consumers in draining mode...")

      # except main thread
      @consumers.each do |_shard_id, consumer|
        consumer[:stop] = true
        consumer.join
      end
    end

    def terminate_timer!
      return if @timer.nil?

      @timer.cancel
      @timer = nil
    end

    # Add new shards and delete unused shards
    def sync_shards!
      @live_shards.transform_values! { |_| false }

      kinesis.shards.each do |shard|
        @live_shards[shard.shard_id] = true
        next if @shards[shard.shard_id]

        @shards[shard.shard_id] = Kcl::Workers::ShardInfo.new(
          shard.shard_id,
          shard.parent_shard_id,
          shard.sequence_number_range
        )

        Kcl.logger.info(message: "Found new shard", shard: shard.to_h)
      end

      @live_shards.each do |shard_id, alive|
        if alive
          begin
            @shards[shard_id] = checkpointer.fetch_checkpoint(@shards[shard_id])
          rescue Kcl::Errors::CheckpointNotFoundError
            Kcl.logger.warn(message: "Not found checkpoint of shard", shard: shard.to_h)
            next
          end
        else
          checkpointer.remove_lease(@shards[shard_id])
          @shards.delete(shard_id)
          @live_shards.delete(shard_id)
          Kcl.logger.info(message: "Remove shard", shard_id: shard_id)
        end
      end

      @shards
    end

    def sync_workers!
      @live_workers.transform_values! { |_| false }

      heartbeater.fetch_workers.each do |worker|
        @live_workers[worker.id] = worker.alive?

        unless @workers[worker.id]
          Kcl.logger.info(message: "Registered new worker", worker: worker.id)
        end

        @workers[worker.id] = worker
      end

      @live_workers.each do |worker_id, alive|
        next if alive

        heartbeater.cleanup(@workers[worker_id])
        @workers.delete(worker_id)
        @live_workers.delete(worker_id)
        Kcl.logger.info(message: "Remove worker", worker: worker_id)
      end

      @workers
    end

    # Count the number of leases hold by worker excluding the processed shard
    def rebalance_shards!
      stats = ::Kcl::Stats.new(id: @id, active_shards: active_shards, worker_ids: @workers.keys.sort)
      stats.validate!

      active_shards.each do |shard_id, shard|
        potential_owner = shard.potential_owner

        # skip if potential owner is already associated with the shard
        next if potential_owner == @id

        # === give own shard away if shard has potential_owner different then @id
        # and current worker does not have active consumer related to the shard
        if potential_owner && @consumers[shard_id] && !@consumers[shard_id][:stop]
          Kcl.logger.info(message: "soft release", shard: shard)
          @consumers[shard_id][:stop] = true

        # === take shard from potential_owner to the worker
        # if the worker has capacity to obtain new shard
        elsif stats.worker_underloaded?
          # skip if shard is abused? && potential owner has capacity?
          next if shard.abused? && @workers[potential_owner] && stats.worker_completed?(potential_owner)

          stats.take_shard_from(potential_owner, shard_id)
          @shards[shard_id] = checkpointer.ask_for_lease(shard, @id)

          Kcl.logger.info(message: "ask release", shard: shard)
        end
      end

      Kcl.logger.info(message: "Rebalancing...", **stats) if stats.rebalancing?
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      Kcl.logger.error(message: "Rebalance failed", to: @id)
    end

    # Process records by shard
    def consume_shards!
      active_shards.each do |shard_id, shard|
        next if @consumers[shard_id]&.alive?

        # the shard has owner already
        next unless shard.can_be_processed_by?(@id)

        # count the shard as consumed
        begin
          @shards[shard_id] = checkpointer.lease(shard, @id)
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
          Kcl.logger.warn(message: "Lease failed of shard", shard: shard.to_h)
          next
        end

        @consumers[shard_id] = Thread.new do
          Thread.current[:uuid] = SecureRandom.uuid
          consumer = Kcl::Workers::Consumer.new(
            shard,
            @record_processor_factory.create_processor,
            kinesis,
            checkpointer
          )
          consumer.consume!
        ensure
          checkpointer.remove_lease_owner(shard) # release the shard
        end
      end
    end

    def active_shards
      @shards.reject { |_shard_id, shard| shard.completed? }
    end

    def cleanup_dead_consumers
      @consumers.delete_if { |_shard_id, consumer| !consumer.alive? }
    end

    private

      def kinesis
        if @kinesis.nil?
          @kinesis = Kcl::Proxies::KinesisProxy.new(Kcl.config)
          Kcl.logger.info(message: "Created Kinesis session in worker")
        end
        @kinesis
      end

      def checkpointer
        if @checkpointer.nil?
          @checkpointer = Kcl::Checkpointer.new(Kcl.config)
          Kcl.logger.info(message: "Created Checkpoint in worker")
        end
        @checkpointer
      end

      def heartbeater
        if @heartbeater.nil?
          @heartbeater = Kcl::Heartbeater.new(Kcl.config)
          @liveness_timeout = @heartbeater.fetch_liveness(self)
        end

        @heartbeater
      end

      def trap_signals
        %i[HUP INT TERM].each do |signal|
          trap signal do
            EM.add_timer(0) { shutdown(signal) }
          end
        end
      end
  end
end
