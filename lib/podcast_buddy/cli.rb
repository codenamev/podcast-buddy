# frozen_string_literal: true

require "optparse"
require "rainbow"

module PodcastBuddy
  # Command Line Interface for PodcastBuddy
  #
  # Handles command line argument parsing, session management, and audio processing
  # for podcast recording and AI interaction.
  #
  # @example Basic usage
  #   cli = PodcastBuddy::CLI.new(ARGV)
  #   cli.run
  #
  # @example With options
  #   cli = PodcastBuddy::CLI.new(["--debug", "-n", "my-podcast"])
  #   cli.run
  class CLI
    def initialize(argv)
      @options = parse_options(argv)
      @tasks = []
      @show_assistant = PodcastBuddy::ShowAssistant.new
    end

    def run
      configure_logger
      configure_session
      setup_dependencies
      start_recording
    rescue Interrupt
      handle_shutdown
      shutdown_tasks!
    end

    private

    def parse_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: podcast_buddy [options]"

        opts.on("--debug", "Run in debug mode") do |v|
          options[:debug] = v
        end

        opts.on("-w", "--whisper MODEL", "Use specific whisper model (default: small.en)") do |v|
          options[:whisper_model] = v
        end

        opts.on("-n", "--name NAME", "A name for the session to label all log files") do |v|
          options[:name] = v
        end
      end.parse!(argv)
      options
    end

    def configure_logger
      if @options[:debug]
        PodcastBuddy.logger.info to_human("Turning on debug mode...", :info)
        PodcastBuddy.logger.level = Logger::DEBUG
      else
        PodcastBuddy.logger.level = Logger::INFO
      end

      PodcastBuddy.logger.formatter = proc do |severity, datetime, progname, msg|
        (severity.to_s == "INFO") ? "#{msg}\n" : "[#{severity}] #{msg}\n"
      end
    end

    def configure_session
      if @options[:whisper_model]
        PodcastBuddy.config.whisper_model = @options[:whisper_model]
        PodcastBuddy.logger.info to_human("Using whisper model: #{@options[:whisper_model]}", :info)
      end

      if @options[:name]
        base_path = "#{PodcastBuddy.root}/tmp/#{@options[:name]}"
        FileUtils.mkdir_p base_path
        PodcastBuddy.session = @options[:name]
        PodcastBuddy.logger.info to_human("Using custom session name: #{@options[:name]}", :info)
        PodcastBuddy.logger.info to_human("  Saving files to: #{PodcastBuddy.session}", :info)
      end
    end

    def setup_dependencies
      PodcastBuddy.logger.info "Setting up dependencies..."
      PodcastBuddy.setup
      PodcastBuddy.logger.info "Setup complete."
      PodcastBuddy.openai_client
    end

    def start_recording
      Sync do |task|
        @co_host = PodcastBuddy::CoHost.new(listener: @show_assistant.listener)
        show_assistant_task = task.async { @show_assistant.start }
        co_host_task = task.async { @co_host.start }
        @tasks = [
          PodcastBuddy::NamedTask.new(name: "Show Assistant", task: show_assistant_task),
          PodcastBuddy::NamedTask.new(name: "Co-Host", task: co_host_task)
        ]

        task.with_timeout(60 * 60 * 2) do
          task.yield until @shutdown
        end
      end
    end

    def handle_shutdown
      PodcastBuddy.logger.info to_human("\nShutting down streams...", :wait)
      @shutdown = true
    end

    def shutdown_tasks!
      @show_assistant.stop
      @co_host&.stop
      @tasks.each do |task|
        PodcastBuddy.logger.info to_human("Waiting for #{task.name} to shutdown...", :wait)
        task&.task&.wait
      end

      PodcastBuddy.logger.info to_human("Generating show notes...", :wait)
      @show_assistant.generate_show_notes
    end

    private

    def to_human(text, label = :info)
      case label.to_sym
      when :info
        Rainbow(text).blue
      when :wait
        Rainbow(text).yellow
      when :input
        Rainbow(text).black.bg(:yellow)
      when :success
        Rainbow(text).green
      else
        text
      end
    end
  end
end
