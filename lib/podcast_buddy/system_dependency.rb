# frozen_string_literal: true

module PodcastBuddy
  class SystemDependency < Struct.new(:type, :name, keyword_init: true)
    attr_accessor :name
    attr_reader :type

    def initialize(name:, type: :system)
      @name = name
      @type = type || :system
    end

    def self.auto_install!(name)
      system_dependency = new(name: name, type: :system)
      system_dependency.install unless system_dependency.installed?
    end

    def installed?
      PodcastBuddy.logger.info "Checking for system dependency: #{name}..."
      if name.to_s == "whisper"
        Dir.exist?("whisper.cpp")
      else
        system("brew list -1 #{name} > /dev/null") || system("type -a #{name}")
      end
    end

    def install
      PodcastBuddy.logger.info "Installing #{name}..."
      originating_directory = Dir.pwd
      if name.to_s == "whisper"
        Dir.chdir(PodcastBuddy.root)
        PodcastBuddy.logger.info `git clone https://github.com/ggerganov/whisper.cpp`
        Dir.chdir("whisper.cpp")
        PodcastBuddy.logger.info "Downloading GGML model: #{PodcastBuddy.whisper_model}"
        PodcastBuddy.logger.info `bash ./models/download-ggml-model.sh #{PodcastBuddy.whisper_model}`
        PodcastBuddy.logger.info `make && make stream`
      else
        `brew list #{name} || brew install #{name}`
      end
    ensure
      Dir.chdir(originating_directory)
    end
  end
end
