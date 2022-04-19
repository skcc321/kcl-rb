# typed: true
# frozen_string_literal: true

module Kcl
  module Workers
    class RecordCheckpointer
      def initialize(shard, checkpointer)
        @shard = shard
        @checkpointer = checkpointer
      end

      def update_checkpoint(sequence_number)
        # checkpoint the last sequence of a closed shard
        @shard.checkpoint = sequence_number || Kcl::Checkpoints::Sentinel::SHARD_END
        @shard.lease_timeout = (Time.now.utc + Kcl.config.dynamodb_failover_seconds).to_s
        @checkpointer.update_checkpoint(@shard)
      end
    end
  end
end
