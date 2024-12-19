module PodcastBuddy
  # Handles listening and processing of audio input
  class Listener
    # @return [Queue] queue for storing transcriptions
    attr_reader :transcription_queue, :transcriber

    # Initialize a new Listener
    # @param transcriber [PodcastBuddy::Transcriber] the transcriber to use
    # @param whisper_command [String] the system command to use for streaming whisper
    # @param whisper_logger [Logger] the logger to use for whisper
    def initialize(transcriber:, whisper_command: PodcastBuddy.whisper_command, whisper_logger: PodcastBuddy.whisper_logger)
      @transcriber = transcriber
      @transcription_queue = Queue.new
      @shutdown = false
      @whisper_command = whisper_command || PodcastBuddy.whisper_command
      @whisper_logger = whisper_logger || PodcastBuddy.whisper_logger
      @transcription_signal = PodSignal.new
      @listening_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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

    def subscribe(&block)
      @transcription_signal.subscribe(&block)
    end

    private

    # Process a single transcription line
    # @param line [String] the transcription line
    def process_transcription(line)
      text = @transcriber.process(line)
      return if text.empty?

      PodcastBuddy.logger.info "Heard: #{text}"
      PodcastBuddy.update_transcript(text)
      @transcription_queue << text
      @transcription_signal.trigger({ text: text, started_at: @listening_start })
      text
    end
  end
end
