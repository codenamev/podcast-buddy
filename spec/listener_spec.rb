# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/podcast_buddy/listener"

RSpec.describe PodcastBuddy::Listener do
  let(:transcriber) { instance_double(PodcastBuddy::Transcriber) }
  let(:listener) { described_class.new(transcriber: transcriber) }

  describe "#initialize" do
    it "initializes with empty transcription queue" do
      expect(listener.transcription_queue).to be_empty
    end
  end

  describe "#subscribe" do
    it "allows subscribing to transcriptions" do
      received_text = nil
      listener.subscribe { |data| received_text = data[:text] }

      allow(transcriber).to receive(:process).and_return("test transcription")
      result = listener.send(:process_transcription, "input")
      # Wait for PodSignal queue
      sleep 0.01

      expect(result).to eq("test transcription")
      expect(received_text).to eq("test transcription")
    end
  end

  describe "#process_transcription" do
    before do
      allow(transcriber).to receive(:process).and_return("test transcription")
    end

    it "adds transcription to transcription_queue when not listening for questions" do
      expect { listener.send(:process_transcription, "input") }.to change { listener.transcription_queue.size }.by(1)
      expect(listener.transcription_queue.pop).to eq("test transcription")
    end

    it "does not add empty transcriptions to any queue" do
      allow(transcriber).to receive(:process).and_return("")
      expect { listener.send(:process_transcription, "input") }.not_to change { listener.transcription_queue.size }
    end
  end
end
