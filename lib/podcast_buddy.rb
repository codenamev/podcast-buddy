require "net/http"
require "uri"
require "json"
require "open3"
require "logger"
require "async"
require "async/http/faraday"
require "rainbow"
require "openai"

require_relative "podcast_buddy/configuration"
require_relative "podcast_buddy/version"
require_relative "podcast_buddy/system_dependency"
require_relative "podcast_buddy/pod_signal"
require_relative "podcast_buddy/session"
require_relative "podcast_buddy/transcriber"
require_relative "podcast_buddy/listener"

module PodcastBuddy
  class Error < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      @config = Configuration.new
      yield(@config) if block_given?
    end

    def start_session(name: nil)
      @session = Session.new(name: name)
    end

    def setup
      SystemDependency.auto_install!(:git)
      SystemDependency.auto_install!(:sdl2)
      SystemDependency.auto_install!(:whisper)
      SystemDependency.auto_install!(:bat)
      SystemDependency.resolve_whisper_model(whisper_model)
    end
  end

  configure

  def self.root
    Dir.pwd
  end

  def self.session=(name)
    @session = "#{root}/tmp/#{name}"
  end

  def self.session
    @session ||= "#{root}/tmp"
  end

  def self.logger
    @logger ||= Logger.new($stdout, level: Logger::DEBUG)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.openai_client
    PodcastBuddy.config.openai_client
  end

  def self.openai_client=(client)
    PodcastBuddy.config.openai_client = client
  end

  def self.whisper_model
    PodcastBuddy.config.whisper_model
  end

  def self.whisper_command
    PodcastBuddy.config.whisper_command
  end

  def self.whisper_logger=(file_path)
    @whisper_logger ||= Logger.new(file_path, "daily", level: Logger::DEBUG)
  end

  def self.whisper_logger
    @whisper_logger ||= Logger.new("#{session}/whisper.log", "daily", level: Logger::DEBUG)
  end

  def self.topics_log_file=(log_file_path)
    @topics_log_file = log_file_path
  end

  def self.topics_log_file
    @topics_log_file ||= "#{session}/topics-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.summary_log_file=(log_file_path)
    @summary_log_file = log_file_path
  end

  def self.summary_log_file
    @summary_log_file ||= "#{session}/summary-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.transcript_file=(file_path)
    @transcript_file = file_path
  end

  def self.transcript_file
    @transcript_file ||= "#{session}/transcript-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.show_notes_file=(file_path)
    @show_notes_file = file_path
  end

  def self.show_notes_file
    @show_notes_file ||= "#{session}/show-notes-#{Time.new.strftime("%Y-%m-%d")}.md"
  end

  def self.current_transcript
    @current_transcript ||= File.exist?(transcript_file) ? File.read(transcript_file) : ""
  end

  def self.update_transcript(text)
    File.open(transcript_file, "a") { |f| f.puts text }
    current_transcript << text
  end

  def self.current_summary
    @current_summary ||= File.exist?(summary_log_file) ? File.read(summary_log_file) : ""
  end

  def self.update_summary(text)
    @current_summary = text
    File.write(summary_log_file, text)
    @current_summary
  end

  def self.current_topics
    @current_topics ||= File.exist?(topics_log_file) ? File.read(topics_log_file) : ""
  end

  def self.add_to_topics(topics)
    File.open(topics_log_file, "a") { |f| f.puts topics }
    current_topics << topics
  end

  def self.current_topics_file
    @current_topics_file ||= "#{session}/current_topics.md"
  end

  def self.announce_topics(topics)
    File.write(current_topics_file, topics)
    system("bat", current_topics_file, "--language=markdown")
  end

  def self.answer_audio_file_path=(file_path)
    @answer_audio_file_path = file_path
  end

  def self.answer_audio_file_path
    @answer_audio_file_path ||= "response.mp3"
  end

  def self.setup
    SystemDependency.auto_install!(:git)
    SystemDependency.auto_install!(:sdl2)
    SystemDependency.auto_install!(:whisper)
    SystemDependency.auto_install!(:bat)
    SystemDependency.resolve_whisper_model(whisper_model)
  end

  def self.openai_client=(client)
    @openai_client = client
  end

  def self.openai_client
    raise Error, "Please set an OPENAI_ACCESS_TOKEN environment variable." if ENV["OPENAI_ACCESS_TOKEN"].to_s.strip.squeeze.empty?

    @openai_client ||= OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"], log_errors: true)
  end
end
