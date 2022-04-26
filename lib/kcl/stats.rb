# typed: false
# frozen_string_literal: true

# deep_dup
require "active_support"
require "active_support/core_ext"

module Kcl
  class Stats
    class OverprovisionError < StandardError; end

    attr_reader :id, :active_shards, :worker_ids

    def initialize(id:, active_shards:, worker_ids:)
      @id = id
      @active_shards = active_shards
      @worker_ids = worker_ids
    end

    def current_state
      @current_state ||= begin
        result = active_shards.group_by do |_shard_id, shard|
          shard.potential_owner
        end

        { id => [], **result.transform_values { |v| v.map(&:first) } }
      end
    end

    def desired_state
      @desired_state ||= current_state.deep_dup
    end

    def worker_underloaded?(worker_id = id)
      desired_state[worker_id].count < shards_per_worker + bonus
    end

    def worker_completed?(worker_id = id)
      desired_state[worker_id].count <= shards_per_worker
    end

    def take_shard_from(worker_id, shard_id)
      shard_to_move = desired_state[worker_id].delete(shard_id)
      desired_state[id].push(shard_to_move)
    end

    def shards_per_worker
      workers_count == 1 ? shards_count : shards_count / workers_count
    end

    def rebalancing?
      desired_state != current_state
    end

    def overprovisioning?
      workers_count > shards_count
    end

    def validate!
      raise OverprovisionError, "Number of workers is greater then number of shards!" if overprovisioning?
    end

    def bonus
      # FIRST reminder WORKERS can get +1 shard if there are left some shards due to division
      worker_ids[0...reminder].include?(id) ? 1 : 0
    end

    def reminder
      shards_count - (shards_per_worker * workers_count)
    end

    def shards_count
      active_shards.count
    end

    def workers_count
      worker_ids.count
    end

    def to_hash
      {
        id: id,
        current_state: current_state,
        desired_state: desired_state,
        workers_count: workers_count,
        shards_count: shards_count,
        shards_per_worker: shards_per_worker
      }
    end
  end
end
