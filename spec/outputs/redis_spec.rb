require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"

describe LogStash::Outputs::Redis do

  context "integration tests", :redis => true do
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
        insist { redis.llen(key) } == event_count

        # Now check all events for order and correctness.
        event_count.times do |value|
          id, element = redis.blpop(key, 0)
          event = LogStash::Event.new(LogStash::Json.load(element))
          insist { event["sequence"] } == value
          insist { event["message"] } == message
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
  end

  context "Redis#receive in batch mode" do
    # this is a regression test harness to verify fix for https://github.com/logstash-plugins/logstash-output-redis/issues/26
    # TODO: refactor specs above and probably rely on a Redis mock to correctly test the code expected behaviour, the actual
    # tests agains Redis should be moved into integration tests.
    let(:key) { "thekey" }
    let(:payload) { "somepayload"}
    let(:event) { LogStash::Event.new({"message" => "test"}) }
    let(:config) {
      {
        "key" => key,
        "data_type" => "list",
        "batch" => true,
        "batch_events" => 50,
       }
    }
    let(:redis) { described_class.new(config) }

    it "should call buffer_receive" do
      redis.register
      expect(redis).to receive(:buffer_receive).exactly(10000).times.and_call_original
      expect(redis).to receive(:flush).exactly(200).times

      # I was able to reproduce the LocalJumpError: unexpected next exception at around 50
      # consicutive invocations. setting to 10000 should reproduce it for any environment
      # I have no clue at this point why this problem does not happen at every invocation
      1.upto(10000) do
        expect{redis.receive(event)}.to_not raise_error
      end
    end
  end
end

