require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"
require 'securerandom'

describe LogStash::Outputs::Redis do

  context "integration tests", :integration => true do
    shared_examples_for "writing to redis list" do |extra_config|
      let(:key) { SecureRandom.hex }
      let(:event_count) { Flores::Random.integer(0..10000) }
      let(:message) { SecureRandom.hex }  # We use hex generation to avoid escaping issues on Windows
      let(:default_config) {
        {
          "key" => key,
          "data_type" => "list",
          "host" => "localhost"
        }
      }
      let(:redis_config) {
        default_config.merge(extra_config || {})
      }
      let(:redis_output) { described_class.new(redis_config) }

      before do
        redis_output.register
        event_count.times do |i|
          event = LogStash::Event.new("sequence" => i, "message" => message)
          redis_output.receive(event)
        end
        redis_output.close
      end

      it "should successfully send all events to redis" do
        redis = Redis.new(:host => "127.0.0.1")

        # The list should contain the number of elements our agent pushed up.
        insist { redis.llen(key) } == event_count

        # Now check all events for order and correctness.
        event_count.times do |value|
          id, element = redis.blpop(key, 0)
          event = LogStash::Event.new(LogStash::Json.load(element))
          insist { event.get("sequence") } == value
          insist { event.get("message") } == message
        end

        # The list should now be empty
        insist { redis.llen(key) } == 0
      end
    end

    context "when batch_mode is false" do
      include_examples "writing to redis list"
    end

    context "when batch_mode is true" do
      batch_events = Flores::Random.integer(1..1000)
      batch_settings = {
        "batch" => true,
        "batch_events" => batch_events
      }

      include_examples "writing to redis list", batch_settings do

        # A canary to make sure we're actually enabling batch mode
        # in this shared example.
        it "should have batch mode enabled" do
          expect(redis_config).to include("batch")
          expect(redis_config["batch"]).to be_truthy
        end
      end
    end


    shared_examples_for "writing to redis sortedset" do |extra_config|
      let(:key) { SecureRandom.hex }
      let(:event_count) { Flores::Random.integer(12..1000) } # Minimum 12 to test two digits cases
      let(:default_config) {
        {
          "key" => key,
          "data_type" => "sortedset",
          "host" => "localhost",
          "priority_field" => "epoch"
        }
      }
      let(:redis_config) {
        default_config.merge(extra_config || {})
      }
      let(:redis_output) { described_class.new(redis_config) }

      before do
        redis = Redis.new(:host => "127.0.0.1")
        insist { redis.zcard(key) } == 0
        redis.close()

        redis_output.register

        event_count_1 = event_count / 2
        event_count_2 = event_count - event_count_1

        # Add a half of events in non reverse order
        event_count_1.times do |i|
          event = LogStash::Event.new("message" => { "i" => i }, "epoch" => i )
          redis_output.receive(event)
        end
        # And add a half of events in reverse order to verify that events are sorted
        event_count_2.times do |j|
          i = event_count - j - 1
          event = LogStash::Event.new("message" => { "i" => i },  "epoch" => i )
          redis_output.receive(event)
        end

        redis_output.close
      end

      it "should successfully send all events to redis" do
        redis = Redis.new(:host => "127.0.0.1")

        # The sorted set should contain the number of elements our agent pushed up.
        insist { redis.zcard(key) } == event_count

        # Now check all events for order and correctness.
        event_count.times do |i|
          # Non reverse order
          item  = redis.zrange(key, i, i).first
          event = LogStash::Event.new(LogStash::Json.load(item))
          insist { event.get("[message][i]") } == i
          insist { event.get("[epoch]") } == i
        end
      end

      after "should clear the sortedset" do
        redis = Redis.new(:host => "127.0.0.1")

        redis.zremrangebyrank(key, 0, -1)
        # The list should now be empty
        insist { redis.zcard(key) } == 0
      end
    end


    context "when batch_mode is false" do
      include_examples "writing to redis sortedset"
    end

    #context "when batch_mode is true" do
    #  batch_events = Flores::Random.integer(1..1000)
    #  batch_settings = {
    #    "batch" => true,
    #    "batch_events" => batch_events
    #  }

    #  include_examples "writing to redis sortedset", batch_settings do

        # A canary to make sure we're actually enabling batch mode
        # in this shared example.
     #   it "should have batch mode enabled" do
     #     expect(redis_config).to include("batch")
     #     expect(redis_config["batch"]).to be_truthy
     #   end
     # end
    #end

  end
end

