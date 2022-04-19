# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kcl::Worker do
  include_context "use_kinesis"
  include_context "use_dynamodb"

  let(:record_processor_factory) { double("record_processor_factory") }
  let(:worker) { Kcl::Worker.new("test-worker", record_processor_factory) }
  let(:worker_id) { worker.instance_variable_get("@id") }

  before do
    allow(record_processor_factory).to receive(:create_processor)
  end

  describe "#sync_shards!" do
    before do
      expect(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original.exactly(5).times
    end

    subject { worker.sync_shards! }

    it { expect(subject.keys.size).to eq(5) }
  end

  describe "#rebalance_shards" do
    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "same stuck worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "dead another worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "alive another worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 20).to_s
              })
            )

        worker.heartbeat!
        worker.sync_shards!
        worker.sync_workers!
      end

      subject { worker.rebalance_shards! }

      it do
        pending("TODO: reflect changes in the code")
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id
          )
        ))
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id
          )
        ))
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000004",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id
          )
        ))

        subject
      end
    end
  end

  describe "#consume_shards!" do
    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "same stuck worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "dead another worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003" } }).and_return(
              DynamoGetItemResponse.new(item: {
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "alive another worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 20).to_s
              })
            )

        worker.heartbeat!
        worker.sync_shards!
        worker.sync_workers!
        # worker.rebalance_shards!
      end

      subject { worker.consume_shards! }

      it do
        pending("TODO: reflect changes in the code")
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id
          )
        ))
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id
          )
        ))
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000004",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id
          )
        ))

        subject
      end
    end
  end
end
