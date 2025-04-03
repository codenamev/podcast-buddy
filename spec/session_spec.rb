# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::Session do
  let(:session) { described_class.new }

  describe "#initialize" do
    it "sets a default name based on current timestamp" do
      expect(session.name).to match(/\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}/)
    end

    it "allows setting a custom name" do
      custom_session = described_class.new(name: "custom")
      expect(custom_session.name).to eq("custom")
    end

    it "creates the base path directory" do
      expect(File).to exist(session.base_path)
    end
  end

  describe "#transcript_log" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "transcript.log")
      expect(session.transcript_log).to eq(expected_path)
    end
  end

  describe "#summary_log" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "summary.log")
      expect(session.summary_log).to eq(expected_path)
    end
  end

  describe "#topics_log" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "topics.log")
      expect(session.topics_log).to eq(expected_path)
    end
  end

  describe "#show_notes_path" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "show-notes.md")
      expect(session.show_notes_path).to eq(expected_path)
    end
  end

  describe "#whisper_log" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "whisper.log")
      expect(session.whisper_log).to eq(expected_path)
    end
  end

  describe "#answer_audio_file" do
    it "returns the correct file path" do
      expected_path = File.join(session.base_path, "response.mp3")
      expect(session.answer_audio_file).to eq(expected_path)
    end
  end

  describe "#current_transcript" do
    context "when transcript file exists" do
      before { File.write(session.transcript_log, "Test transcript") }
      after { FileUtils.rm_f(session.transcript_log) }

      it "returns the content of the transcript file" do
        expect(session.current_transcript).to eq("Test transcript")
      end
    end

    context "when transcript file does not exist" do
      before { FileUtils.rm_f(session.transcript_log) }

      it "returns an empty string" do
        expect(session.current_transcript).to eq("")
      end
    end
  end

  describe "#update_transcript" do
    after { FileUtils.rm_f(session.transcript_log) }

    it "appends text to the transcript file" do
      session.update_transcript("First line")
      session.update_transcript("Second line")
      expect(File.read(session.transcript_log)).to include("First line", "Second line")
    end
  end

  describe "#current_summary" do
    context "when summary file exists" do
      before { File.write(session.summary_log, "Test summary") }
      after { FileUtils.rm_f(session.summary_log) }

      it "returns the content of the summary file" do
        expect(session.current_summary).to eq("Test summary")
      end
    end

    context "when summary file does not exist" do
      before { FileUtils.rm_f(session.summary_log) }

      it "returns an empty string" do
        expect(session.current_summary).to eq("")
      end
    end
  end

  describe "#update_summary" do
    after { FileUtils.rm_f(session.summary_log) }

    it "writes text to the summary file" do
      session.update_summary("New summary")
      expect(File.read(session.summary_log)).to eq("New summary")
    end
  end

  describe "#current_topics" do
    context "when topics file exists" do
      before { File.write(session.topics_log, "Test topics") }
      after { FileUtils.rm_f(session.topics_log) }

      it "returns the content of the topics file" do
        expect(session.current_topics).to eq("Test topics")
      end
    end

    context "when topics file does not exist" do
      before { FileUtils.rm_f(session.topics_log) }

      it "returns an empty string" do
        expect(session.current_topics).to eq("")
      end
    end
  end

  describe "#add_to_topics" do
    after { FileUtils.rm_f(session.topics_log) }

    it "appends topics to the topics file" do
      session.add_to_topics("First topic")
      session.add_to_topics("Second topic")
      expect(File.read(session.topics_log)).to include("First topic", "Second topic")
    end
  end

  describe "#announce_topics" do
    after { FileUtils.rm_f(session.topics_log) }

    it "writes topics to the file and displays them" do
      expect(session).to receive(:system).with("bat", session.topics_log, "--language=markdown")
      session.announce_topics("New topics")
      expect(File.read(session.topics_log)).to eq("New topics")
    end
  end
end
