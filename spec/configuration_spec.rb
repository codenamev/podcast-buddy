# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::Configuration do
  let(:config) { described_class.new }

  describe "initialization" do
    it "sets default values" do
      expect(config.root).to eq(Dir.pwd)
      expect(config.whisper_model).to eq("small.en-q5_1")
      expect(config.logger).to be_a(Logger)
    end
  end

  describe "attribute accessors" do
    it "allows reading and writing root" do
      config.root = "/test/path"
      expect(config.root).to eq("/test/path")
    end

    it "allows reading and writing whisper_model" do
      config.whisper_model = "test_model"
      expect(config.whisper_model).to eq("test_model")
    end

    it "allows reading and writing logger" do
      new_logger = Logger.new($stderr)
      config.logger = new_logger
      expect(config.logger).to eq(new_logger)
    end

    it "allows writing openai_client" do
      client = double("OpenAI::Client")
      config.openai_client = client
      expect(config.instance_variable_get(:@openai_client)).to eq(client)
    end
  end

  describe "#openai_client" do
    context "when OPENAI_ACCESS_TOKEN is not set" do
      before { ENV["OPENAI_ACCESS_TOKEN"] = nil }

      it "raises an error" do
        expect { config.openai_client }.to raise_error("Please set an OPENAI_ACCESS_TOKEN environment variable.")
      end
    end

    context "when OPENAI_ACCESS_TOKEN is set" do
      before { ENV["OPENAI_ACCESS_TOKEN"] = "test_token" }

      it "returns an OpenAI::Client instance" do
        expect(OpenAI::Client).to receive(:new).with(access_token: "test_token", log_errors: true).and_call_original
        expect(config.openai_client).to be_a(OpenAI::Client)
      end

      it "memoizes the client" do
        client = config.openai_client
        expect(config.openai_client).to equal(client)
      end
    end
  end

  describe "#whisper_command" do
    it "returns the expected command string" do
      expected_command = "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-small.en-q5_1.bin -t 8 --step 0 --length 5000 --keep 500 --vad-thold 0.75 --audio-ctx 0 --keep-context -c 1 -l en"
      expect(config.whisper_command).to eq(expected_command)
    end

    it "incorporates changes to whisper_model" do
      config.whisper_model = "test_model"
      expected_command = "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-test_model.bin -t 8 --step 0 --length 5000 --keep 500 --vad-thold 0.75 --audio-ctx 0 --keep-context -c 1 -l en"
      expect(config.whisper_command).to eq(expected_command)
    end
  end
end
