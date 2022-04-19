# typed: false
# frozen_string_literal: true

module Kcl
  module Workers
    class WorkerInfo
      attr_reader :id
      attr_accessor :liveness_timeout

      def initialize(worker_id, liveness_timeout)
        @id = worker_id
        @liveness_timeout = liveness_timeout
      end

      def alive?
        liveness_timeout_datetime && Time.now.utc < liveness_timeout_datetime
      end

      def liveness_timeout_datetime
        return nil if liveness_timeout.to_s.empty?

        Time.parse(liveness_timeout)
      end

      # For debug
      def to_h
        {
          id: id,
          livenes_timeout: livenes_timeout
        }
      end
    end
  end
end
