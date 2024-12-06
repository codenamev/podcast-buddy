# frozen_string_literal: true

module PodcastBuddy
  # Manages configuration for PodcastBuddy
  class Configuration
    attr_accessor :root,
      :whisper_model,
      :logger,
      :topic_extraction_system_prompt,
      :topic_extraction_user_prompt,
      :discussion_system_prompt,
      :discussion_user_prompt
    attr_writer :openai_client

    DEFAULT_TOPIC_EXTRACTION_SYSTEM_PROMPT = <<~PROMPT
      As a podcast assistant, your task is to diligently extract topics related to the discussion on the show and prepare this information in an optimal way for participants to learn more in the closing show notes.

      To achieve this, follow these steps:

      1. Listen to the podcast discussion and identify the main topics covered.
      2. For each main topic, provide a brief summary of what was discussed.
      3. Generate 2-3 questions that participants can ask to delve deeper into each topic.
      4. Organize the information in a structured format that can be used in the closing Show Notes.

      Example Structure:
      - **Some Topic**: Summary of Some Topic
      - **Another Topic**: Summary of Another Topic
      - **Super Cool Topic**: Summary of Super Cool Topic
    PROMPT

    DEFAULT_TOPIC_EXTRACTION_USER_PROMPT = <<~PROMPT
      Here is a snippet from the podcast discussion for you to analyze:
      """
      %{discussion}
      """

      Please extract the topics following the structure above.
    PROMPT

    DEFAULT_DISCUSSION_SYSTEM_PROMPT = <<~PROMPT
      As a kind and helpful podcast co-host. Your task is to keep track of the overall discussion on the show. Additionally, you must be ready to provide a concise summary of the ongoing discussion at any moment and actively participate when asked.

      To achieve this, follow these guidelines:
      1. You are an active participant, and co-host of the show.
      2. Your name is "Buddy".
      3. Listen carefully to the podcast or read the provided transcript.
      4. Take note of key points, arguments, discussions, and any action items mentioned.
      5. Summarize the main points in a few sentences.
      6. Think about this segment, and be prepared to elaborate on any part of the discussion or provide insights when asked.
      7. You must never ask how you can help or provide assistance.
      8. Never provide commentary or response, like "Got it!" or "Great!". Act naturally.

      Here is a brief summary of the latest segment:
      """
      %{summary}
      """

      Let's start with the first segment:
    PROMPT

    DEFAULT_DISCUSSION_USER_PROMPT = <<~PROMPT
      Segment:
      """
      %{discussion}
      """

      Wait for further instructions or questions from the host.
    PROMPT

    def initialize
      @root = Dir.pwd
      @whisper_model = "small.en-q5_1"
      @logger = Logger.new($stdout, level: Logger::INFO)
      @topic_extraction_system_prompt = DEFAULT_TOPIC_EXTRACTION_SYSTEM_PROMPT
      @topic_extraction_user_prompt = DEFAULT_TOPIC_EXTRACTION_USER_PROMPT
      @discussion_system_prompt = DEFAULT_DISCUSSION_SYSTEM_PROMPT
      @discussion_user_prompt = DEFAULT_DISCUSSION_USER_PROMPT
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
