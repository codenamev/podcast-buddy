# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::AudioService do
  let(:service) { described_class.new }
  let(:test_file) { "tmp/test.mp3" }

  describe "#text_to_speech" do
    before do
      allow(PodcastBuddy).to receive(:openai_client).and_return(
        double(audio: double(speech: "audio data"))
      )
    end

    it "converts text to speech and saves to file" do
      expect(File).to receive(:binwrite).with(test_file, "audio data")
      service.text_to_speech("test text", test_file)
    end
  end

  describe "#play_audio" do
    it "plays the audio file using afplay" do
      expect(service).to receive(:system).with("afplay #{test_file}")
      service.play_audio(test_file)
    end
  end
end
