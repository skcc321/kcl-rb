# typed: true
# frozen_string_literal: true

module KclDemo
  class DemoRecordProcessorFactory < Kcl::RecordProcessorFactory
    def create_processor
      KclDemo::DemoRecordProcessor.new
    end
  end
end
