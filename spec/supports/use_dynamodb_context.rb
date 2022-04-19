# typed: false
# frozen_string_literal: true

RSpec.shared_context "use_dynamodb" do
  DynamoGetItemResponse = Struct.new(:item)

  let(:stub_dynamodb_client) { Aws::DynamoDB::Client.new(stub_responses: true) }

  before do
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(stub_dynamodb_client)
  end
end
