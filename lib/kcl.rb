# frozen_string_literal: true

require "kcl/checkpointer"
require "kcl/checkpoints/sentinel"
require "kcl/heartbeater"
require "kcl/config"
require "kcl/errors"
require "kcl/logger"
require "kcl/log_formatter"
require "kcl/proxies/dynamo_db_proxy"
require "kcl/proxies/kinesis_proxy"
require "kcl/record_processor"
require "kcl/record_processor_factory"
require "kcl/types/extended_sequence_number"
require "kcl/types/initialization_input"
require "kcl/types/records_input"
require "kcl/types/shutdown_input"
require "kcl/worker"
require "kcl/workers/consumer"
require "kcl/workers/record_checkpointer"
require "kcl/workers/shard_info"
require "kcl/workers/shutdown_reason"

module Kcl
  def self.configure
    yield config
  end

  def self.config
    @_config ||= Kcl::Config.new
  end

  def self.logger
    @_logger ||= begin
      kcl_logger = config.logger || Kcl::Logger.new($stdout)
      kcl_logger.formatter = Kcl::LogFormatter.new
      kcl_logger
    end
  end
end
