# frozen_string_literal: true

module Kcl
  class RecordProcessor
    def after_initialize(_initialization_input)
      raise NotImplementedError, "You must implement #{self.class}##{__method__}"
    end

    def process_records(_records_input)
      raise NotImplementedError, "You must implement #{self.class}##{__method__}"
    end

    def shutdown(_shutdown_input)
      raise NotImplementedError, "You must implement #{self.class}##{__method__}"
    end
  end
end
