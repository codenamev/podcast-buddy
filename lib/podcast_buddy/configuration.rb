# frozen_string_literal: true

module PodcastBuddy
  # Manages configuration for PodcastBuddy
  class Configuration
    attr_accessor :root, :whisper_model, :logger
    attr_writer :openai_client

    def initialize
      @root = Dir.pwd
      @whisper_model = "small.en-q5_1"
      @logger = Logger.new($stdout, level: Logger::INFO)
    end

    # @return [OpenAI::Client]
    def openai_client
      raise Error, "Please set an OPENAI_ACCESS_TOKEN environment variable." if ENV["OPENAI_ACCESS_TOKEN"].to_s.strip.empty?

      @openai_client ||= OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"], log_errors: true)
    end

    # @return [String]
    def whisper_command
      "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-#{whisper_model}.bin -t 8 --step 0 --length 5000 --keep 500 --vad-thold 0.75 --audio-ctx 0 --keep-context -c 1 -l en"
    end
  end
end
