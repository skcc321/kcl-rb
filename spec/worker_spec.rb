require 'spec_helper'

RSpec.describe Kcl::Worker do
  include_context 'use_kinesis'
  include_context 'use_dynamodb'

  let(:record_processor_factory) { double('record_processor_factory') }
  let(:worker) { Kcl::Worker.new('test-worker', record_processor_factory) }
  let(:worker_id) { worker.instance_variable_get('@id') }

  before do
    allow(record_processor_factory).to receive(:create_processor)
  end

  describe '#sync_shards!' do
    before do
      expect(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original.exactly(5).times
    end

    subject { worker.sync_shards! }

    it { expect(subject.keys.size).to eq(5) }
  end

  describe '#groups_stats!' do
    context "initial execution (blank db)" do
      before do
        worker.sync_shards!
      end

      subject { worker.groups_stats }

      it do
        expect(subject).to eq({
          nil => [
            "shardId-000000000000",
            "shardId-000000000001",
            "shardId-000000000002",
            "shardId-000000000003",
            "shardId-000000000004"
          ]
        })
      end
    end

    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 15).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 15).to_s
          })
        )

        worker.sync_shards!
      end

      subject { worker.groups_stats }

      it do
        expect(subject).to eq({
          worker_id => [
            "shardId-000000000000",
            "shardId-000000000001"
          ],
          nil => [
            "shardId-000000000002",
            "shardId-000000000003",
            "shardId-000000000004"
          ]
        })
      end
    end
  end

  describe '#detailed_stats!' do
    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + Kcl.config.dynamodb_failover_seconds).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "n/a",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - Kcl.config.dynamodb_failover_seconds - 1).to_s
          })
        )

        worker.sync_shards!
      end

      subject { worker.detailed_stats }

      it do
        expect(subject).to eq({
          :groups_stats => {"test-worker"=>["shardId-000000000000"], "n/a"=>["shardId-000000000001"], nil=>["shardId-000000000002", "shardId-000000000003", "shardId-000000000004"]},
          :id => "test-worker",
          :number_of_workers => 1,
          :owner_stats => {"test-worker"=>2, nil=>3},
          :shards_count => 5,
          :shards_per_worker => 5,
        })
      end
    end
  end

  describe '#rebalance_shards' do
    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "same stuck worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "dead another worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "alive another worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 20).to_s
          })
        )

        worker.sync_shards!
      end

      subject { worker.rebalance_shards! }

      it do
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

  describe '#consume_shards!' do
    context "subsequent execution" do
      before do
        allow(stub_dynamodb_client).to receive(:get_item).with(anything).and_call_original
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000000",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000001",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "same stuck worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PENDING_OWNER_KEY => worker_id,
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000002",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "dead another worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now - 1).to_s
          })
        )
        allow(stub_dynamodb_client).to receive(:get_item).with({table_name: Kcl.config.dynamodb_table_name, key: { Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003" }}).and_return(
          OpenStruct.new(item: {
            Kcl::Checkpointer::DYNAMO_DB_LEASE_PRIMARY_KEY => "shardId-000000000003",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_OWNER_KEY => "alive another worker",
            Kcl::Checkpointer::DYNAMO_DB_LEASE_TIMEOUT_KEY => (Time.now + 20).to_s
          })
        )

        worker.sync_shards!
        worker.rebalance_shards!
      end

      subject { worker.consume_shards! }

      it do
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
