# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/podcast_buddy/transcriber"

RSpec.describe PodcastBuddy::Transcriber do
  let(:transcriber) { described_class.new }

  describe "#initialize" do
    it "initializes with an empty full_transcript" do
      expect(transcriber.full_transcript).to eq("")
    end
  end

  describe "#process" do
    context "with valid input" do
      it "processes and adds text to full_transcript" do
        input = "[00:00:00.000 --> 00:00:05.000]  Hello, world!"
        result = transcriber.process(input)
        expect(result).to eq("Hello, world! ")
        expect(transcriber.full_transcript).to eq("Hello, world! ")
      end

      it "handles multiple lines" do
        input1 = "[00:00:00.000 --> 00:00:05.000]  Hello,"
        input2 = "[00:00:05.000 --> 00:00:10.000]  world!"
        transcriber.process(input1)
        transcriber.process(input2)
        expect(transcriber.full_transcript).to eq("Hello, world! ")
      end
    end

    context "with invalid input" do
      it "returns empty string for [BLANK_AUDIO]" do
        input = "[00:00:00.000 --> 00:00:05.000]  [BLANK_AUDIO]"
        result = transcriber.process(input)
        expect(result).to eq("")
        expect(transcriber.full_transcript).to eq("")
      end

      it "handles empty input" do
        result = transcriber.process("")
        expect(result).to eq("")
        expect(transcriber.full_transcript).to eq("")
      end
    end
  end

  describe "#latest" do
    before do
      transcriber.process("[00:00:00.000 --> 00:00:05.000]  This is a long sentence.")
      transcriber.process("[00:00:05.000 --> 00:00:10.000]  It has multiple parts.")
    end

    it "returns the latest portion of the transcript" do
      expect(transcriber.latest(23)).to eq("It has multiple parts. ")
    end

    it "returns the full transcript if length is greater than transcript length" do
      expect(transcriber.latest(100)).to eq("This is a long sentence. It has multiple parts. ")
    end

    it "returns an empty string if transcript is empty" do
      empty_transcriber = described_class.new
      expect(empty_transcriber.latest).to eq("")
    end
  end
end
