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
        show_assistant_task = task.async { @show_assistant.start }
        question_listener_task = task.async { wait_for_question_start(@show_assistant.listener) }
        @tasks = [
          PodcastBuddy::NamedTask.new(name: "Show Assistant", task: @show_assistant_task),
          PodcastBuddy::NamedTask.new(name: "Question Listener", task: question_listener_task)
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
      @tasks.each do |task|
        PodcastBuddy.logger.info to_human("Waiting for #{task.name} to shutdown...", :wait)
        task&.task&.wait
      end

      PodcastBuddy.logger.info to_human("Generating show notes...", :wait)
      @show_assistant.generate_show_notes
    end

    def wait_for_question_start(listener)
      Async do |parent|
        PodcastBuddy.logger.info Rainbow("Press ").blue + Rainbow("Enter").black.bg(:yellow) + Rainbow(" to signal a question start...").blue
        loop do
          PodcastBuddy.logger.debug("Shutdown: wait_for_question...") and break if @shutdown

          input = ""
          Timeout.timeout(5) do
            input = gets
            PodcastBuddy.logger.debug("Input received...") if input.include?("\n")
            listener.listen_for_question! if input.include?("\n")
          rescue Timeout::Error
            next
          end

          next unless listener.listening_for_question

          PodcastBuddy.logger.info to_human("🎙️ Listening for quesiton. Press ", :wait) + to_human("Enter", :input) + to_human(" to signal the end of the question...", :wait)
          wait_for_question_end(listener)
        end
      end
    end

    def wait_for_question_end(listener)
      Async do
        loop do
          PodcastBuddy.logger.debug("Shutdown: wait_for_question_end...") and break if @shutdown

          sleep 0.1 and next if !listener.listening_for_question

          input = ""
          Timeout.timeout(5) do
            input = gets
            PodcastBuddy.logger.debug("Input received...") if input.include?("\n")
            next unless input.to_s.include?("\n")
          rescue Timeout::Error
            PodcastBuddy.logger.debug("Input timeout...")
            next
          end

          if input.empty?
            next
          else
            PodcastBuddy.logger.info "End of question signal.  Generating answer..."
            question = listener.stop_listening_for_question!
            answer_question(question, listener).wait
            PodcastBuddy.logger.info Rainbow("Press ").blue + Rainbow("Enter").black.bg(:yellow) + Rainbow(" to signal a question start...").blue
            break
          end
        end
      end
    end

    def answer_question(question, listener)
      Async do
        @show_assistant.summarize_latest if PodcastBuddy.session.current_summary.to_s.empty?
        latest_context = "#{PodcastBuddy.session.current_summary}\nTopics discussed recently:\n---\n#{PodcastBuddy.session.current_topics.split("\n").last(10)}\n---\n"
        previous_discussion = listener.transcriber.latest(1_000)
        PodcastBuddy.logger.info "Answering question:\n#{question}"
        PodcastBuddy.logger.debug "Context:\n---#{latest_context}\n---\nPrevious discussion:\n---#{previous_discussion}\n---\nAnswering question:\n---#{question}\n---"
        response = PodcastBuddy.openai_client.chat(parameters: {
          model: "gpt-4o-mini",
          messages: [
            {role: "system", content: format(PodcastBuddy.config.discussion_system_prompt, {summary: PodcastBuddy.current_summary})},
            {role: "user", content: question}
          ],
          max_tokens: 150
        })
        answer = response.dig("choices", 0, "message", "content").strip
        PodcastBuddy.logger.debug "Answer: #{answer}"
        audio_service.text_to_speech(answer, PodcastBuddy.answer_audio_file_path)
        PodcastBuddy.logger.debug("Answer converted to speech: #{PodcastBuddy.answer_audio_file_path}")
        PodcastBuddy.logger.debug("Playing answer...")
        audio_service.play_audio(PodcastBuddy.answer_audio_file_path)
      end
    end

    private

    def audio_service
      @audio_service ||= AudioService.new
    end

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

    def show_notes_messages
      [
        {role: "system", content: "You are a kind and helpful podcast assistant helping to take notes for the show, and extract useful information being discussed for listeners."},
        {role: "user", content: "Transcript:\n---\n#{PodcastBuddy.current_transcript}\n---\n\nTopics:\n---\n#{PodcastBuddy.current_topics}\n---\n\nUse the above transcript and topics to create Show Notes in markdown that outline the discussion.  Extract a breif summary that describes the overall conversation, the people involved and their roles, and sentiment of the topics discussed.  Follow the summary with a list of helpful links to any libraries, products, or other resources related to the discussion. Cite sources."}
      ]
    end
  end
end
