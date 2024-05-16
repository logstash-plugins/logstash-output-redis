require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"

describe LogStash::Outputs::Redis do

  FIXTURES_PATH = File.expand_path('../../fixtures', File.dirname(__FILE__))
  PORT = 16379
  SSL_PORT = 26379

  context "integration tests", :integration => true do
    shared_examples_for "writing to redis list" do |extra_config|
      let(:timeout) { 5 }
      let(:key) { 10.times.collect { rand(10).to_s }.join("") }
      let(:event_count) { Flores::Random.integer(0..10000) }
      let(:message) { Flores::Random.text(0..100) }
      let(:default_config) {
        {
          "key" => key,
          "data_type" => "list",
          "host" => "redis",
          "port" => PORT,
          "timeout" => timeout
        }
      }
      let(:redis_config) {
        default_config.merge(extra_config || {})
      }
      let(:redis_output) { described_class.new(redis_config) }

      let(:redis) do
        ssl_enabled = redis_config['ssl_enabled'] == true
        cli_config = {
          :host => redis_config["host"],
          :port => redis_config["port"] || PORT,
          :timeout => timeout,
          :ssl => ssl_enabled
        }

        cli_config[:ssl_params] = redis_output.send(:setup_ssl_params) if ssl_enabled
        Redis.new(cli_config)
      end

      before do
        redis_output.register
        event_count.times do |i|
          event = LogStash::Event.new("sequence" => i, "message" => message)
          redis_output.receive(event)
        end
        redis_output.close
      end

      after do
        redis.del(key)
      end

      it "should successfully send all events to redis" do
        # The list should contain the number of elements our agent pushed up.
        expect(redis.llen(key)).to eql event_count

        # Now check all events for order and correctness.
        event_count.times do |value|
          id, element = redis.blpop(key, :timeout => timeout)
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

    context "when SSL is enabled" do
      context "with client certificate and key" do
        ssl_config = {
          "host" => "redis_ssl",
          "port" => SSL_PORT,
          "ssl_enabled" => true,
          "ssl_certificate_authorities" => File.join(FIXTURES_PATH, 'certificates/ca.crt'),
          "ssl_certificate" => File.join(FIXTURES_PATH, 'certificates/client.crt'),
          "ssl_key" => File.join(FIXTURES_PATH, 'certificates/client.key')
        }

        include_examples "writing to redis list", ssl_config
      end

      context "with ssl_verification_mode => none" do
        ssl_config = {
          "host" => "redis_ssl",
          "port" => SSL_PORT,
          "ssl_enabled" => true,
          "ssl_verification_mode" => "none",
          "ssl_certificate" => File.join(FIXTURES_PATH, 'certificates/client.crt'),
          "ssl_key" => File.join(FIXTURES_PATH, 'certificates/client.key')
        }

        include_examples "writing to redis list", ssl_config
      end

    end

    context "when batch_mode is true" do
      batch_events = Flores::Random.integer(1..1000)
      batch_settings = {
        "batch" => true,
        "batch_events" => batch_events,
        "port" => PORT
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
