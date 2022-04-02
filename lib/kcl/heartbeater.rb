# frozen_string_literal: true

require "time"
require "kcl/workers/worker_info"

module Kcl
  class Heartbeater
    DYNAMO_DB_LIVENESS_PRIMARY_KEY = "worker_id"
    DYNAMO_DB_LIVENESS_TIMEOUT_KEY = "liveness_timeout"

    attr_reader :dynamodb

    # @param [Kcl::Config] config
    def initialize(config)
      @dynamodb = Kcl::Proxies::DynamoDbProxy.new(config)
      @table_name = config.workers_health_table_name

      return if @dynamodb.exists?(@table_name)

      @dynamodb.create_table(
        @table_name,
        [{
          attribute_name: DYNAMO_DB_LIVENESS_PRIMARY_KEY,
          attribute_type: "S"
        }],
        [{
          attribute_name: DYNAMO_DB_LIVENESS_PRIMARY_KEY,
          key_type: "HASH"
        }],
        {
          read_capacity_units: config.dynamodb_read_capacity,
          write_capacity_units: config.dynamodb_write_capacity
        }
      )
      Kcl.logger.info(message: "Created DynamoDB table", table_name: @table_name)
    end

    def fetch_liveness(worker)
      liveness = @dynamodb.get_item(
        @table_name,
        { DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker.id }
      )
      return if liveness.nil?

      Kcl.logger.debug(message: "Retrieves liveness of worker", worker: worker.id)
      liveness[DYNAMO_DB_LIVENESS_TIMEOUT_KEY]
    end

    def ping(worker)
      now = Time.now.utc
      next_liveness_timeout = now + (Kcl.config.sync_interval_seconds * 2)

      item = {
        DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker.id,
        DYNAMO_DB_LIVENESS_TIMEOUT_KEY.to_s => next_liveness_timeout.to_s
      }

      result = @dynamodb.put_item(@table_name, item)

      if result
        next_liveness_timeout.to_s
      else
        Kcl.logger.warn(mesage: "Failed to ping", worker: worker.id)
        worker.liveness_timeout
      end
    end

    def fetch_workers
      result = @dynamodb.client.scan(
        table_name: @table_name
      )

      if result
        result.items.map do |attrs|
          Kcl::Workers::WorkerInfo.new(
            attrs[DYNAMO_DB_LIVENESS_PRIMARY_KEY],
            attrs[DYNAMO_DB_LIVENESS_TIMEOUT_KEY]
          )
        end
      else
        Kcl.logger.warn(mesage: "Failed to get workes list")
        []
      end
    end

    def cleanup(worker)
      result = @dynamodb.remove_item(
        @table_name,
        { DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker.id }
      )

      if result
        nil
      else
        Kcl.logger.warn(message: "Failed to remove worker", worker: worker.id)
        worker.liveness_timeout
      end
    end
  end
end
