# typed: true
# frozen_string_literal: true

module Kcl
  module Workers
    class ShardInfo
      attr_reader :shard_id,
        :parent_shard_id,
        :starting_sequence_number,
        :ending_sequence_number

      attr_accessor :assigned_to, :reassigned_to, :checkpoint, :lease_timeout

      # @param [String] shard_id
      # @param [String] parent_shard_id
      # @param [Hash] sequence_number_range
      def initialize(shard_id, parent_shard_id, sequence_number_range)
        @shard_id        = shard_id
        @parent_shard_id = parent_shard_id || 0
        @starting_sequence_number = sequence_number_range[:starting_sequence_number]
        @ending_sequence_number   = sequence_number_range[:ending_sequence_number]
        @assigned_to = nil
        @reassigned_to = nil
        @checkpoint      = nil
        @lease_timeout   = nil
      end

      def potential_owner
        pending_owner || lease_owner
      end

      def lease_owner
        @assigned_to
      end

      def lease_owner=(assigned_to)
        @assigned_to = assigned_to
      end

      def pending_owner
        @reassigned_to
      end

      def pending_owner=(assigned_to)
        @reassigned_to = assigned_to
      end

      def completed?
        @checkpoint == Kcl::Checkpoints::Sentinel::SHARD_END
      end

      def abendoned?
        !lease_timeout || Time.now.utc > lease_timeout_datetime
      end

      def abused?
        !abendoned?
      end

      def can_be_processed_by?(id)
        # another worker abandoned the shard I got new_owner
        (lease_owner != id && abendoned? && pending_owner == id)
      end

      def lease_timeout_datetime
        return nil if lease_timeout.to_s.empty?

        Time.parse(lease_timeout)
      end

      # For debug
      def to_h
        {
          shard_id: shard_id,
          parent_shard_id: parent_shard_id,
          starting_sequence_number: starting_sequence_number,
          ending_sequence_number: ending_sequence_number,
          assigned_to: assigned_to,
          checkpoint: checkpoint,
          lease_timeout: lease_timeout
        }
      end
    end
  end
end
