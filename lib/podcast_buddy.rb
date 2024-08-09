# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "open3"
require "logger"

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

  def self.whisper_logger
    @whisper_logger ||= Logger.new("tmp/whisper.log", "daily")
  end

  def self.discussion_log_file
    @discussion_log_file ||= "#{root}/tmp/discussion-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.transcript_file
    @transcript_file ||= "#{root}/tmp/transcript-#{Time.new.strftime("%Y-%m-%d")}.log"
  end

  def self.update_transcript(text)
    File.open(transcript_file, "a") { |f| f.puts text }
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
end
