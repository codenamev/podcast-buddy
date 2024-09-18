# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/podcast_buddy/listener"

RSpec.describe PodcastBuddy::Listener do
  let(:transcriber) { instance_double(PodcastBuddy::Transcriber) }
  let(:listener) { described_class.new(transcriber: transcriber) }

  describe "#initialize" do
    it "initializes with empty queues and not listening for questions" do
      expect(listener.transcription_queue).to be_empty
      expect(listener.question_queue).to be_empty
      expect(listener.listening_for_question).to be false
    end
  end

  describe "#current_discussion" do
    it "returns the current discussion from the transcription queue" do
      listener.transcription_queue << "First part. "
      listener.transcription_queue << "Second part. "
      expect(listener.current_discussion).to eq("First part. Second part.")
    end

    it "returns an empty string when the transcription queue is empty" do
      expect(listener.current_discussion).to eq("")
    end

    it "resets the current discussion on subsequent calls" do
      listener.transcription_queue << "First part. "
      expect(listener.current_discussion).to eq("First part.")

      listener.transcription_queue << "Second part. "
      expect(listener.current_discussion).to eq("Second part.")
    end

    it "retains the current discussion on subsequent calls without any new queue additions" do
      listener.transcription_queue << "First part. "
      expect(listener.current_discussion).to eq("First part.")
      expect(listener.current_discussion).to eq("First part.")
    end
  end

  describe "#listen_for_question!" do
    it "marks listening_for_question as true" do
      expect { listener.listen_for_question! }.to change { listener.listening_for_question }.from(false).to(true)
      expect { listener.listen_for_question! }.not_to change { listener.listening_for_question }
    end

    it "clears question_queue when toggled on" do
      listener.question_queue << "test question"
      expect { listener.listen_for_question! }.to change { listener.question_queue.empty? }.from(false).to(true)
    end
  end

  describe "#stop_listening_for_question!" do
    it "marks listening_for_question as false" do
      expect { listener.listen_for_question! }.to change { listener.listening_for_question }.from(false).to(true)
      expect { listener.stop_listening_for_question! }.to change { listener.listening_for_question }.from(true).to(false)
      expect { listener.stop_listening_for_question! }.not_to change { listener.listening_for_question }
    end

    it "returns the question" do
      listener.question_queue << "test question"
      expect(listener.stop_listening_for_question!).to eq("test question")
    end

    it "clears the question_queue" do
      listener.question_queue << "test question"
      expect { listener.stop_listening_for_question! }.to change { listener.question_queue.empty? }.from(false).to(true)
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

    it "adds transcription to question_queue when listening for questions" do
      listener.listen_for_question!
      expect { listener.send(:process_transcription, "input") }.to change { listener.question_queue.size }.by(1)
      expect(listener.question_queue.pop).to eq("test transcription")
    end

    it "does not add empty transcriptions to any queue" do
      allow(transcriber).to receive(:process).and_return("")
      expect { listener.send(:process_transcription, "input") }.not_to change { listener.transcription_queue.size }
      expect { listener.send(:process_transcription, "input") }.not_to change { listener.question_queue.size }
    end
  end
end
