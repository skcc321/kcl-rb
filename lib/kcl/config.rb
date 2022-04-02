# frozen_string_literal: true

module Kcl
  class Config
    attr_accessor :dynamodb_endpoint,
      :dynamodb_failover_seconds,
      :dynamodb_read_capacity,
      :dynamodb_table_name,
      :dynamodb_write_capacity,
      :kinesis_endpoint,
      :kinesis_stream_name,
      :log_level,
      :logger,
      :max_records,
      :sync_interval_seconds,
      :use_ssl,
      :workers_health_table_name

    # Set default values
    def initialize
      @dynamodb_endpoint = nil
      @dynamodb_failover_seconds = 10
      @dynamodb_read_capacity = 10
      @dynamodb_table_name = nil
      @dynamodb_write_capacity = 10
      @kinesis_endpoint = nil
      @kinesis_stream_name = nil
      @logger = nil
      @max_records = 10
      @sync_interval_seconds = 2
      @use_ssl = nil
      @workers_health_table_name = nil
    end
  end
end
