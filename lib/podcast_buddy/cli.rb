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
    LabeledTask = Struct.new(:name, :task, keyword_init: true)

    def initialize(argv)
      @options = parse_options(argv)
      @tasks = []
      @listener = nil
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
        @listener = PodcastBuddy::Listener.new(transcriber: PodcastBuddy::Transcriber.new)
        listener_task = task.async { @listener.start }
        periodic_summarization_task = task.async { periodic_summarization(@listener) }
        question_listener_task = task.async { wait_for_question_start(@listener) }
        @tasks = [
          LabeledTask.new(name: "Listener", task: listener_task),
          LabeledTask.new(name: "Periodic Summarizer", task: periodic_summarization_task),
          LabeledTask.new(name: "question listener", task: question_listener_task)
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
      PodcastBuddy.logger.info to_human("Waiting for Listener to shutdown...", :wait)
      @listener&.stop
      @tasks.each do |task|
        PodcastBuddy.logger.info to_human("Waiting for #{task.name} to shutdown...", :wait)
        task.task.wait
      end

      PodcastBuddy.logger.info to_human("Generating show notes...", :wait)
      generate_show_notes
    end

    def periodic_summarization(listener, interval = 15)
      Async do
        loop do
          PodcastBuddy.logger.debug("Shutdown: periodic_summarization...") and break if @shutdown

          sleep interval
          summarize_latest(listener)
        rescue => e
          PodcastBuddy.logger.warn "[summarization] periodic summarization failed: #{e.message}"
        end
      end
    end

    def summarize_latest(listener)
      current_discussion = listener.current_discussion
      return if current_discussion.empty?

      PodcastBuddy.logger.debug "[periodic summarization] Latest transcript: #{current_discussion}"
      extract_topics_and_summarize(current_discussion)
    end

    def extract_topics_and_summarize(text)
      Async do |parent|
        parent.async { update_topics(text) }
        parent.async { think_about(text) }
      end
    end

    def update_topics(text)
      Async do
        PodcastBuddy.logger.debug "Looking for topics related to: #{text}"
        response = PodcastBuddy.openai_client.chat(parameters: {
          model: "gpt-4o-mini",
          messages: topic_extraction_messages(text),
          max_tokens: 500
        })
        new_topics = response.dig("choices", 0, "message", "content").gsub("NONE", "").strip

        PodcastBuddy.session.announce_topics(new_topics)
        PodcastBuddy.session.add_to_topics(new_topics)
      end
    end

    def think_about(text)
      Async do
        PodcastBuddy.logger.debug "Summarizing current discussion..."
        response = PodcastBuddy.openai_client.chat(parameters: {
          model: "gpt-4o",
          messages: discussion_messages(text),
          max_tokens: 250
        })
        new_summary = response.dig("choices", 0, "message", "content").strip
        PodcastBuddy.logger.info to_human("Thoughts: #{new_summary}", :info)
        PodcastBuddy.session.update_summary(new_summary)
      end
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
        summarize_latest(listener) if PodcastBuddy.session.current_summary.to_s.empty?
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
        text_to_speech(answer)
        PodcastBuddy.logger.debug("Answer converted to speech: #{PodcastBuddy.answer_audio_file_path}")
        play_answer
      end
    end

    def text_to_speech(text)
      response = PodcastBuddy.openai_client.audio.speech(parameters: {
        model: "tts-1",
        input: text,
        voice: "onyx",
        response_format: "mp3",
        speed: 1.0
      })
      File.binwrite(PodcastBuddy.answer_audio_file_path, response)
    end

    def play_answer
      PodcastBuddy.logger.debug("Playing answer...")
      system("afplay #{PodcastBuddy.answer_audio_file_path}")
    end

    def generate_show_notes
      return if PodcastBuddy.current_transcript.strip.empty?

      response = PodcastBuddy.openai_client.chat(parameters: {
        model: "gpt-4o",
        messages: show_notes_messages,
        max_tokens: 500
      })
      show_notes = response.dig("choices", 0, "message", "content").strip
      File.open(PodcastBuddy.session.show_notes_path, "w") do |file|
        file.puts show_notes
      end

      PodcastBuddy.logger.info to_human("Show notes saved to: #{PodcastBuddy.session.show_notes_path}", :success)
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

    def topic_extraction_messages(text)
      [
        {role: "system", content: PodcastBuddy.config.topic_extraction_system_prompt},
        {role: "user", content: format(PodcastBuddy.config.topic_extraction_user_prompt, {discussion: text})}
      ]
    end

    def discussion_messages(text)
      [
        {role: "system", content: format(PodcastBuddy.config.discussion_system_prompt, {summary: PodcastBuddy.current_summary})},
        {role: "user", content: format(PodcastBuddy.config.discussion_user_prompt, {discussion: text})}
      ]
    end

    def show_notes_messages
      [
        {role: "system", content: "You are a kind and helpful podcast assistant helping to take notes for the show, and extract useful information being discussed for listeners."},
        {role: "user", content: "Transcript:\n---\n#{PodcastBuddy.current_transcript}\n---\n\nTopics:\n---\n#{PodcastBuddy.current_topics}\n---\n\nUse the above transcript and topics to create Show Notes in markdown that outline the discussion.  Extract a breif summary that describes the overall conversation, the people involved and their roles, and sentiment of the topics discussed.  Follow the summary with a list of helpful links to any libraries, products, or other resources related to the discussion. Cite sources."}
      ]
    end
  end
end
