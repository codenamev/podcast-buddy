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
end
