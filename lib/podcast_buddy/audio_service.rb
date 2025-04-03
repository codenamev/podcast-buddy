# frozen_string_literal: true

module PodcastBuddy
  # Handles audio-related operations
  class AudioService
    def text_to_speech(text, output_path)
      response = PodcastBuddy.openai_client.audio.speech(parameters: {
        model: "tts-1",
        input: text,
        voice: "onyx",
        response_format: "mp3",
        speed: 1.0
      })
      File.binwrite(output_path, response)
    end

    def play_audio(file_path)
      system("afplay #{file_path}")
    end
  end
end
