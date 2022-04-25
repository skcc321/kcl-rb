# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kcl::Worker, :aggregate_failures do
  include_context "use_kinesis"
  include_context "use_dynamodb"

  let(:record_processor_factory) { double("record_processor_factory") }
  let(:worker) { Kcl::Worker.new("test-worker", record_processor_factory) }
  let(:worker_2) { Kcl::Worker.new("test-worker-2", record_processor_factory) }
  let(:worker_id) { worker.instance_variable_get("@id") }
  let(:worker_2_id) { worker.instance_variable_get("@id") }

  before do
    Timecop.freeze(Time.local(1989))
    allow(record_processor_factory).to receive(:create_processor)
  end

  let(:next_liveness_timeout) { Time.now.utc + (Kcl.config.sync_interval_seconds * 3) }

  after do
    Timecop.return
  end

  describe "#perform" do
    subject { worker.perform }

    it do
      expect(worker).to receive(:heartbeat!).ordered
      expect(worker).to receive(:sync_shards!).ordered
      expect(worker).to receive(:sync_workers!).ordered
      expect(worker).to receive(:rebalance_shards!).ordered
      expect(worker).to receive(:cleanup_dead_consumers).ordered
      expect(worker).to receive(:consume_shards!).ordered

      subject
    end
  end

  describe "#heartbeat!" do
    before do
      allow(stub_dynamodb_client).to receive(:get_item)
        .with(table_name: Kcl.config.workers_health_table_name, key: anything)
        .and_call_original.exactly(1).time
    end

    subject { worker.heartbeat! }

    it "sends put request to dynamodb with liveness timeout" do
      expect(stub_dynamodb_client).to receive(:put_item).with(
        table_name: Kcl.config.workers_health_table_name,
        item: {
          Kcl::Heartbeater::DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker.id,
          Kcl::Heartbeater::DYNAMO_DB_LIVENESS_TIMEOUT_KEY.to_s => next_liveness_timeout.to_s
        }
      )

      subject
    end
  end

  describe "#sync_shards!" do
    before do
      expect(stub_dynamodb_client).to receive(:get_item)
        .with(table_name: Kcl.config.dynamodb_table_name, key: anything)
        .and_call_original.exactly(5).times
    end

    subject { worker.sync_shards! }

    it "returns 5 shards" do
      expect(subject.keys.size).to eq(5)
    end
  end

  describe "#sync_workers!" do
    before do
      allow(stub_dynamodb_client).to receive(:scan)
        .with(table_name: Kcl.config.workers_health_table_name)
        .and_return(
          DynamoScanItemsResponse.new(
            [
              {
                Kcl::Heartbeater::DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker.id,
                Kcl::Heartbeater::DYNAMO_DB_LIVENESS_TIMEOUT_KEY.to_s => next_liveness_timeout.to_s
              },
              {
                Kcl::Heartbeater::DYNAMO_DB_LIVENESS_PRIMARY_KEY.to_s => worker_2.id,
                Kcl::Heartbeater::DYNAMO_DB_LIVENESS_TIMEOUT_KEY.to_s => next_liveness_timeout.to_s
              }
            ]
          )
        )
    end

    it "returns 2 workers" do
      expect(worker.sync_workers!.keys.size).to eq(2)
      expect(worker_2.sync_workers!.keys.size).to eq(2)
    end
  end

  describe "#rebalance_shards" do
    context "subsequent execution" do
      before do
        worker.instance_variable_set(:@workers, {
          worker.id => Kcl::Workers::WorkerInfo.new(worker.id, next_liveness_timeout),
          worker_2.id => Kcl::Workers::WorkerInfo.new(worker_2.id, next_liveness_timeout)
        })

        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" } }).and_return(
              DynamoGetItemResponse.new({
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker.id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" } }).and_return(
              DynamoGetItemResponse.new({
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker.id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002" } }).and_return(
              DynamoGetItemResponse.new({
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "dead another worker",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003" } }).and_return(
              DynamoGetItemResponse.new({
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_2.id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 20).to_s
              })
            )
        allow(stub_dynamodb_client).to receive(:get_item).with(
          { table_name: Kcl.config.dynamodb_table_name,
            key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000004" } }).and_return(
              DynamoGetItemResponse.new({
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000004",
                Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker.id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_2.id,
                Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 20).to_s
              })
            )

        worker.sync_shards!
      end

      subject do
        worker.rebalance_shards!
      end

      it do
        expect(stub_dynamodb_client).not_to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000"
          )
        ))
        expect(stub_dynamodb_client).not_to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001"
          )
        ))
        expect(stub_dynamodb_client).not_to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003"
          )
        ))
        expect(stub_dynamodb_client).not_to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000004"
          )
        ))
        expect(stub_dynamodb_client).to receive(:put_item).with(a_hash_including(
          item: a_hash_including(
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id
          )
        ))

        subject
      end
    end
  end
end
