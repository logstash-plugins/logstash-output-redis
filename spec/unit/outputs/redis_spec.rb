require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/redis"
require "logstash/json"
require "redis"
require "flores/random"
require "flores/pki"

describe LogStash::Outputs::Redis do

  context "Redis#receive in batch mode" do
    # this is a regression test harness to verify fix for https://github.com/logstash-plugins/logstash-output-redis/issues/26
    # TODO: refactor specs above and probably rely on a Redis mock to correctly test the code expected behaviour, the actual
    # tests agains Redis should be moved into integration tests.
    let(:key) { "thekey" }
    let(:config) {
      {
        "key" => key,
        "data_type" => "list",
        "batch" => true,
        "batch_events" => 50,
        "batch_timeout" => 3600 * 24,
        # ^ this a very large timeout value to prevent the Flush Timer thread in Stud::Buffer from calling flush
        # it screws with the RSpec expect().to receive thread safety.
       }
    }
    let(:redis) { described_class.new(config) }

    it "should call buffer_receive" do
      redis.register
      expect(redis).to receive(:buffer_receive).exactly(10000).times.and_call_original
      expect(redis).to receive(:flush).exactly(200).times
      expect(redis).not_to receive(:on_flush_error)

      # I was able to reproduce the LocalJumpError: unexpected next exception at around 50
      # consicutive invocations. setting to 10000 should reproduce it for any environment
      # I have no clue at this point why this problem does not happen at every invocation
      10000.times do |i|
        expect{redis.receive(LogStash::Event.new({"message" => "test-#{i}"}))}.to_not raise_error
      end
    end
  end

  context "with SSL enabled" do
    let(:config) {{ "ssl_enabled" => true, "key" => "key", "data_type" => "list" }}
    subject(:plugin) { described_class.new(config) }

    context "and not providing a certificate/key pair" do
      it "registers without error" do
        expect { plugin.register }.to_not raise_error
      end
    end

    context "and providing a certificate/key pair" do
      let(:cert_key_pair) { Flores::PKI.generate }
      let(:certificate) do
        path = Tempfile.new('certificate').path
        IO.write(path, cert_key_pair.first.to_s)
        path
      end
      let(:key) do
        path = Tempfile.new('key').path
        IO.write(path, cert_key_pair[1].to_s)
        path
      end
      let(:config) { super().merge("ssl_certificate" => certificate, "ssl_key" => key) }

      it "registers without error" do
        expect { plugin.register }.to_not raise_error
      end
    end

    FIXTURES_PATH = File.expand_path('../../fixtures', File.dirname(__FILE__))

    context "and plain-text certificate/key" do
      let(:key_file) { File.join(FIXTURES_PATH, 'certificates/redis.key') }
      let(:crt_file) { File.join(FIXTURES_PATH, 'certificates/redis.crt') }
      let(:config) { super().merge("ssl_certificate" => crt_file, "ssl_key" => key_file) }

      it "registers without error" do
        expect { plugin.register }.to_not raise_error
      end

      context 'with password set' do
        let(:config) { super().merge("ssl_key_passphrase" => 'ignored') }

        it "registers without error" do # password simply ignored
          expect { plugin.register }.to_not raise_error
        end
      end

      context 'with supported protocol' do
        let(:config) { super().merge("ssl_supported_protocols" => %w[TLSv1.2 TLSv1.3]) }

        it 'configures minimum TLS version' do
          plugin.register
          ssl_params = plugin.send(:setup_ssl_params)
          expect(ssl_params).to match(a_hash_including(:min_version => :TLS1_2, :max_version => :TLS1_3))
        end
      end
    end

    context "with only ssl_certificate set" do
      let(:config) { super().merge("ssl_certificate" => File.join(FIXTURES_PATH, 'certificates/redis.crt')) }

      it "should raise a configuration error to request also `ssl_key`" do
        expect { plugin.register }.to raise_error(LogStash::ConfigurationError, /Using an `ssl_certificate` requires an `ssl_key`/)
      end
    end

    context "with only ssl_key set" do
      let(:config) { super().merge("ssl_key" => File.join(FIXTURES_PATH, 'certificates/redis.key')) }

      it "should raise a configuration error to request also `ssl_key`" do
        expect { plugin.register }.to raise_error(LogStash::ConfigurationError, /An `ssl_certificate` is required when using an `ssl_key`/)
      end
    end

    context "with ssl_certificate_authorities" do
      let(:certificate_path) { File.join(FIXTURES_PATH, 'certificates/redis.crt') }
      let(:config) do
        super().merge('ssl_certificate_authorities' => [certificate_path])
      end

      it "sets cert_store values" do
        ssl_store = double(OpenSSL::X509::Store.new)
        allow(ssl_store).to receive(:set_default_paths)
        allow(ssl_store).to receive(:add_file)
        allow(subject).to receive(:new_ssl_certificate_store).and_return(ssl_store)
        subject.send :setup_ssl_params
        expect(ssl_store).to have_received(:add_file).with(certificate_path)
      end
    end

    context "CAs certificates" do
      it "includes openssl default paths" do
        ssl_store = double(OpenSSL::X509::Store.new)
        allow(ssl_store).to receive(:set_default_paths)
        allow(plugin).to receive(:new_ssl_certificate_store).and_return(ssl_store)
        subject.send :setup_ssl_params
        expect(ssl_store).to have_received(:set_default_paths)
      end
    end
  end
end
