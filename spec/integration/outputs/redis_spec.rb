require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"

describe LogStash::Outputs::Redis do

  context "integration tests", :integration => true do
    shared_examples_for "writing to redis list" do |extra_config|
      let(:key) { 10.times.collect { rand(10).to_s }.join("") }
      let(:event_count) { Flores::Random.integer(0..10000) }
      let(:message) { Flores::Random.text(0..100) }
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
        expect(redis.llen(key)).to eql event_count

        # Now check all events for order and correctness.
        event_count.times do |value|
          id, element = redis.blpop(key, 0)
          event = LogStash::Event.new(LogStash::Json.load(element))
          expect(event.get("sequence")).to eql value
          expect(event.get("message")).to eql message
        end

        # The list should now be empty
        expect(redis.llen(key)).to eql 0
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
  end
end
