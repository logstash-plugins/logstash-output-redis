require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"

# integration tests ---------------------

describe LogStash::Outputs::Redis, :redis => true do
  

  describe "ship lots of events to a list" do
    key = 10.times.collect { rand(10).to_s }.join("")
    event_count = 10000 + rand(500)

    config <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
          type => "generator"
        }
      }
      output {
        redis {
          host => "127.0.0.1"
          key => "#{key}"
          data_type => list
        }
      }
    CONFIG

    agent do
      # Query redis directly and inspect the goodness.
      redis = Redis.new(:host => "127.0.0.1")

      # The list should contain the number of elements our agent pushed up.
      insist { redis.llen(key) } == event_count

      # Now check all events for order and correctness.
      event_count.times do |value|
        id, element = redis.blpop(key, 0)
        event = LogStash::Event.new(LogStash::Json.load(element))
        insist { event["sequence"] } == value
        insist { event["message"] } == "hello world"
      end

      # The list should now be empty
      insist { redis.llen(key) } == 0
    end # agent
  end

  describe "batch mode" do
    key = 10.times.collect { rand(10).to_s }.join("")
    event_count = 200000

    config <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
          type => "generator"
        }
      }
      output {
        redis {
          host => "127.0.0.1"
          key => "#{key}"
          data_type => list
          batch => true
          batch_timeout => 5
          timeout => 5
        }
      }
    CONFIG

    agent do
      # we have to wait for close to execute & flush the last batch.
      # otherwise we might start doing assertions before everything has been
      # sent out to redis.
      sleep 2

      redis = Redis.new(:host => "127.0.0.1")

      # The list should contain the number of elements our agent pushed up.
      insist { redis.llen(key) } == event_count

      # Now check all events for order and correctness.
      event_count.times do |value|
        id, element = redis.blpop(key, 0)
        event = LogStash::Event.new(LogStash::Json.load(element))
        insist { event["sequence"] } == value
        insist { event["message"] } == "hello world"
      end

      # The list should now be empty
      insist { redis.llen(key) } == 0
    end # agent
  end

  describe "converts US-ASCII to utf-8 without failures" do
    key = 10.times.collect { rand(10).to_s }.join("")

    config <<-CONFIG
      input {
        generator {
          charset => "US-ASCII"
          message => "\xAD\u0000"
          count => 1
          type => "generator"
        }
      }
      output {
        redis {
          host => "127.0.0.1"
          key => "#{key}"
          data_type => list
        }
      }
    CONFIG

    agent do
      # Query redis directly and inspect the goodness.
      redis = Redis.new(:host => "127.0.0.1")

      # The list should contain no elements.
      insist { redis.llen(key) } == 1
    end # agent
  end
end

# unit tests ---------------------

describe LogStash::Outputs::Redis do

  let(:data_type) { 'list' }
  let(:cfg) { {'key' => 'foo', 'data_type' => data_type} }
  
  subject do
    LogStash::Plugin.lookup("output", "redis")
      .new(cfg)
  end

  context 'renamed redis commands' do
    let(:cfg) { {'key' => 'foo', 'data_type' => data_type, 'codec' => 'json', 'rpush' => 'test rpush', 'publish' => 'test publish'} }

    before do
      subject.register
    end

    it 'sets the renamed commands in the command map' do
      subject.on_flush_error(RuntimeError.new) # forces a connection

      command_map = subject.instance_variable_get("@redis").client.command_map
      expect(command_map[:rpush]).to eq cfg['rpush']
      expect(command_map[:publish]).to eq cfg['publish']
    end

  end

end

