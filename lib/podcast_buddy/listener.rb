module PodcastBuddy
  # Handles listening and processing of audio input
  class Listener
    # @return [Queue] queue for storing transcriptions
    attr_reader :transcription_queue, :transcriber

    # @return [Queue] queue for storing questions
    attr_reader :question_queue

    # @return [Boolean] indicates if currently listening for a question
    attr_reader :listening_for_question

    # Initialize a new Listener
    # @param transcriber [PodcastBuddy::Transcriber] the transcriber to use
    # @param whisper_command [String] the system command to use for streaming whisper
    # @param whisper_logger [Logger] the logger to use for whisper
    def initialize(transcriber:, whisper_command: PodcastBuddy.whisper_command, whisper_logger: PodcastBuddy.whisper_logger)
      @transcriber = transcriber
      @transcription_queue = Queue.new
      @question_queue = Queue.new
      @current_discussion = ""
      @listening_for_question = false
      @shutdown = false
      @whisper_command = whisper_command || PodcastBuddy.whisper_command
      @whisper_logger = whisper_logger || PodcastBuddy.whisper_logger
    end

    # Start the listening process
    def start
      Sync do |parent|
        Open3.popen3(@whisper_command) do |_stdin, stdout, stderr, _thread|
          error_log_task = parent.async { stderr.each { |line| @whisper_logger.error line } }
          output_log_task = parent.async { stdout.each { |line| @whisper_logger.debug line } }

          PodcastBuddy.logger.info "Listening..."

          while (line = stdout.gets)
            break if @shutdown

            PodcastBuddy.logger.debug("Shutdown: process_audio_stream...") and break if @shutdown

            last_transcription_task = parent.async { process_transcription(line) }
          end

          error_log_task.wait
          output_log_task.wait
          last_transcription_task&.wait
        end
      end
    end

    # Stop the listening process
    def stop
      @shutdown = true
    end

    # Enter question listening mode
    def listen_for_question!
      @listening_for_question = true
      @question_queue.clear
    end

    # Exit question listening mode and return running question
    def stop_listening_for_question!
      @listening_for_question = false
      question = ""
      question << @question_queue.pop until @question_queue.empty?
      question
    end

    # @return [String] current discussion still in the @transcription_queue
    def current_discussion
      return @current_discussion if @transcription_queue.empty?

      latest_transcriptions = []
      latest_transcriptions << transcription_queue.pop until transcription_queue.empty?
      @current_discussion = latest_transcriptions.join.strip
    end

    private

    # Process a single transcription line
    # @param line [String] the transcription line
    def process_transcription(line)
      text = @transcriber.process(line)
      return if text.empty?

      if @listening_for_question
        PodcastBuddy.logger.info "Heard Question: #{text}"
        @question_queue << text
      else
        PodcastBuddy.logger.info "Heard: #{text}"
        PodcastBuddy.update_transcript(text)
        @transcription_queue << text
      end
    end
  end
end
