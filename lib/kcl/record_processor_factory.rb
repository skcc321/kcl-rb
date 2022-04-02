# frozen_string_literal: true

module Kcl
  class RecordProcessorFactory
    def create_processor
      raise NotImplementedError, "You must implement #{self.class}##{__method__}"
    end
  end
end
