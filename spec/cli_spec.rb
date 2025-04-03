# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::CLI do
  let(:cli) { described_class.new([]) }

  describe "#initialize" do
    it "parses command line options" do
      cli = described_class.new(["--debug"])
      expect(cli.instance_variable_get(:@options)).to include(debug: true)
    end

    it "handles whisper model option" do
      cli = described_class.new(["-w", "base.en"])
      expect(cli.instance_variable_get(:@options)).to include(whisper_model: "base.en")
    end

    it "handles session name option" do
      cli = described_class.new(["-n", "test-session"])
      expect(cli.instance_variable_get(:@options)).to include(name: "test-session")
    end
  end

  describe "#run" do
    let(:show_assistant) { instance_double(PodcastBuddy::ShowAssistant) }
    let(:listener) { instance_double(PodcastBuddy::Listener) }

    before do
      allow(PodcastBuddy).to receive(:logger).and_return(Logger.new(nil))
      allow(PodcastBuddy).to receive(:setup)
      allow(PodcastBuddy).to receive(:openai_client).and_return(double(chat: {"choices" => [{"message" => {"content" => "test"}}]}))
      allow(PodcastBuddy::ShowAssistant).to receive(:new).and_return(show_assistant)
      allow(show_assistant).to receive(:start)
      allow(show_assistant).to receive(:stop)
      allow(show_assistant).to receive(:generate_show_notes)
      allow(show_assistant).to receive(:listener).and_return(listener)
      allow(listener).to receive(:subscribe)
    end

    it "configures logger and session" do
      allow(cli).to receive(:start_recording)
      expect(PodcastBuddy.logger).to receive(:level=)
      cli.run
    end

    it "handles interrupt gracefully" do
      allow(cli).to receive(:start_recording).and_raise(Interrupt)
      expect(cli).to receive(:handle_shutdown)
      cli.run
    end

    it "starts and stops show assistant" do
      allow(cli).to receive(:start_recording).and_raise(Interrupt)
      expect(show_assistant).to receive(:stop)
      cli.run
    end
  end
end
