require "net/http"
require "uri"
require "json"
require "open3"
require "logger"
require "async"
require "async/http/faraday"
require "rainbow"

require "bundler/inline"

require_relative "podcast_buddy/version"
require_relative "podcast_buddy/system_dependency"
require_relative "podcast_buddy/pod_signal"

module PodcastBuddy
  class Error < StandardError; end

  def self.root
    Dir.pwd
  end

  def self.logger
    @logger ||= Logger.new($stdout, level: Logger::DEBUG)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.whisper_model
    "small.en"
  end

  def self.whisper_command
    "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-#{PodcastBuddy.whisper_model}.bin -t 4 --step 0 --length 5000 --keep 500 --vad-thold 0.60 --audio-ctx 0 --keep-context -c 1"
  end

  def self.whisper_logger
    @whisper_logger ||= Logger.new("tmp/whisper.log", "daily")
  end

  def self.topics_log_file
    @topics_log_file ||= "#{root}/tmp/topics-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.summary_log_file
    @summary_log_file ||= "#{root}/tmp/summary-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.transcript_file
    @transcript_file ||= "#{root}/tmp/transcript-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.show_notes_file
    @show_notes_file ||= "#{root}/tmp/show-notes-#{Time.new.strftime("%Y-%m-%d")}.md"
  end

  def self.update_transcript(text)
    File.open(transcript_file, "a") { |f| f.puts text }
  end

  def self.current_summary
    @current_summary ||= File.exist?(summary_log_file) ? File.read(summary_log_file) : ""
  end

  def self.add_to_summary(text)
    File.open(summary_log_file, "a") { |f| f.puts text }
    @current_summary << text
  end

  def self.current_topics
    @current_topics ||= File.exist?(topics_log_file) ? File.read(topics_log_file) : ""
  end

  def self.add_to_topics(topics)
    File.open(topics_log_file, "a") { |f| f.puts topics }
    @current_topics << topics
  end

  def self.answer_audio_file_path
    "response.mp3"
  end

  def self.setup
    gemfile do
      source "https://rubygems.org"
      gem "ruby-openai"
    end

    require "openai"
    logger.info "Gems installed and loaded!"
    SystemDependency.auto_install!(:git)
    SystemDependency.auto_install!(:sdl2)
    SystemDependency.auto_install!(:whisper)
  end

  def self.openai_client
    raise Error, "Please set an OPENAI_ACCESS_TOKEN environment variable." if ENV["OPENAI_ACCESS_TOKEN"].to_s.strip.squeeze.empty?

    @openai_client ||= OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"], log_errors: true)
  end
end
