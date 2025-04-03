# frozen_string_literal: true

require "fileutils"

module PodcastBuddy
  # Manages session-specific data for PodcastBuddy
  class Session
    attr_reader :name, :base_path

    def initialize(name: nil)
      @name = name || Time.now.strftime("%Y-%m-%d_%H-%M-%S")
      @base_path = File.join(PodcastBuddy.config.root, "tmp", @name)
      FileUtils.mkdir_p(@base_path)
    end

    # @return [String]
    def transcript_log
      File.join(@base_path, "transcript.log")
    end

    # @return [String]
    def summary_log
      File.join(@base_path, "summary.log")
    end

    # @return [String]
    def topics_log
      File.join(@base_path, "topics.log")
    end

    # @return [String]
    def show_notes_path
      File.join(@base_path, "show-notes.md")
    end

    # @return [String]
    def whisper_log
      File.join(@base_path, "whisper.log")
    end

    # @return [String]
    def answer_audio_file
      File.join(@base_path, "response.mp3")
    end

    def current_transcript
      File.exist?(transcript_log) ? File.read(transcript_log) : ""
    end

    def update_transcript(text)
      File.open(transcript_log, "a") { |f| f.puts text }
    end

    def current_summary
      File.exist?(summary_log) ? File.read(summary_log) : ""
    end

    def update_summary(text)
      File.write(summary_log, text)
    end

    def current_topics
      File.exist?(topics_log) ? File.read(topics_log) : ""
    end

    def add_to_topics(topics)
      File.open(topics_log, "a") { |f| f.puts topics }
    end

    def announce_topics(topics)
      File.write(topics_log, topics)
      system("bat", topics_log, "--language=markdown")
    end
  end
end
