require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"

describe LogStash::Outputs::Redis do

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
        "batch_timeout" => 60
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

