# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::ShowAssistant do
  let(:session) { instance_double(PodcastBuddy::Session) }
  let(:show_assistant) { described_class.new(session: session) }

  describe "#initialize" do
    it "creates a new listener with transcriber" do
      expect(show_assistant.instance_variable_get(:@listener)).to be_a(PodcastBuddy::Listener)
    end
  end

  describe "#start" do
    let(:listener) { instance_double(PodcastBuddy::Listener) }
    let(:listener_task) { instance_double(Async::Task) }
    let(:summarization_task) { instance_double(Async::Task) }

    before do
      allow(listener).to receive(:start).and_return(instance_double(Async::Task))
      show_assistant.instance_variable_set(:@listener, listener)
    end

    it "starts listener and summarization tasks" do
      allow(show_assistant).to receive(:periodic_summarization).and_return(instance_double(Async::Task))

      # Simulate Async behavior
      # Mark shutdown flag so the task doesn't yield and hang
      show_assistant.instance_variable_set(:@shutdown, true)
      Sync do |task|
        show_assistant.start
      end

      expect(listener).to have_received(:start)
    end
  end

  describe "#stop" do
    let(:listener) { instance_double(PodcastBuddy::Listener) }

    before do
      allow(session).to receive(:show_notes_path).and_return(File.join("tmp", "show-notes.md"))
      allow(PodcastBuddy).to receive(:current_transcript).and_return("")
      allow(PodcastBuddy.logger).to receive(:info)
      allow(listener).to receive(:stop)
      show_assistant.instance_variable_set(:@listener, listener)
    end

    it "sets shutdown flag" do
      show_assistant.stop
      expect(show_assistant.instance_variable_get(:@shutdown)).to be true
    end

    it "stops the listener" do
      expect(listener).to receive(:stop)
      show_assistant.stop
    end
  end

  describe "#summarize_latest" do
    let(:listener) { instance_double(PodcastBuddy::Listener) }

    before do
      show_assistant.instance_variable_set(:@current_discussion, "test discussion")
      show_assistant.instance_variable_set(:@listener, listener)
    end

    it "extracts topics and summarizes when discussion exists" do
      expect(show_assistant).to receive(:extract_topics_and_summarize).with("test discussion")
      show_assistant.summarize_latest
    end

    it "does nothing when discussion is empty" do
      show_assistant.instance_variable_set(:@current_discussion, "")
      expect(show_assistant).not_to receive(:extract_topics_and_summarize)
      show_assistant.summarize_latest
    end
  end
end
