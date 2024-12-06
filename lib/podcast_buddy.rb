require "net/http"
require "uri"
require "json"
require "open3"
require "logger"
require "async"
require "async/http/faraday"
require "rainbow"
require "openai"

require_relative "podcast_buddy/cli"
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
    @session = Session.new(name: name)
  end

  def self.session
    @session ||= Session.new
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
    @whisper_logger ||= Logger.new(session.whisper_log, "daily", level: Logger::DEBUG)
  end

  def self.answer_audio_file_path
    session.answer_audio_file
  end

  # Delegate session methods
  class << self
    extend Forwardable
    def_delegators :session, :current_transcript, :update_transcript,
                            :current_summary, :update_summary,
                            :current_topics, :add_to_topics, :announce_topics
  end
end
