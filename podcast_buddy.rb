require "net/http"
require "uri"
require "json"
require "open3"
require "logger"

require "bundler/inline"
require_relative "podcast_buddy/system_dependency"

module PodcastBuddy
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

PodcastBuddy.logger.formatter = proc do |severity, datetime, progname, msg|
  if severity.to_s == "INFO"
    "#{msg}\n"
  else
    "[#{severity}] #{msg}\n"
  end
end
PodcastBuddy.logger.info "Setting up dependencies..."
PodcastBuddy.setup
PodcastBuddy.logger.info "Setup complete."

# OpenAI API client setup
client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"], log_errors: true)

# Custom Signal class
class PodSignal
  def initialize
    @listeners = []
    @queue = Queue.new
    start_listener_thread
  end

  def subscribe(&block)
    @listeners << block
  end

  def trigger(data = nil)
    @queue << data
  end

  private

  def start_listener_thread
    Thread.new do
      loop do
        data = @queue.pop
        @listeners.each { |listener| listener.call(data) }
      end
    end
  end
end

# Signals for question detection
question_signal = PodSignal.new
end_signal = PodSignal.new

# Initialize variables
@latest_transcription = ""
@question_transcription = ""
@full_transcription = ""
@listening_for_question = false
@shutdown_flag = false
@threads = []
@transcription_queue = Queue.new

# Method to extract topics and summarize
def extract_topics_and_summarize(client, text)
  current_discussion = File.exists?(PodcastBuddy.discussion_log_file) ? File.read(PodcastBuddy.discussion_log_file) : ""
  current_discussion.rstrip.squeeze!
  messages = []
  if current_discussion.length > 1
    messages << { role: "user", content: "Given the prior summary and topics:\n---\n#{current_discussion}\n---" }
    messages << { role: "user", content: "Continue the running summary and list of topcs using the following discussion:\n---#{text}\n---" }
  else
    messages << { role: "user", content: "Extract topics and summarize the following discussion:\n---#{text}\n---" }
  end
  response = client.chat(parameters: {
    model: "gpt-4o",
    messages: messages,
    max_tokens: 150
  })
  response.dig("choices", 0, "message", "content").strip
end

def answer_question(client, question)
  latest_context = `tail -n 25 #{PodcastBuddy.discussion_log_file}`
  previous_discussion = @full_transcription.split("\n").last(25)
  PodcastBuddy.logger.info "Context:\n---#{latest_context}\n---\nPrevious discussion:\n---#{previous_discussion}\n---\nAnswering question:\n---#{question}\n---"
  response = client.chat(parameters: {
    model: "gpt-4o",
    messages: [
      { role: "system", content: "You are a kind and helpful podcast assistant helping to answer questions as them come up during a recording. Keep the answer succinct and without speculation." },
      { role: "user", content: "Context:\n#{latest_context}\n\nPrevious Discussion:\n#{previous_discussion}\n\nQuestion:\n#{question}\n\nAnswer:" }
    ],
    max_tokens: 150
  })
  response.dig("choices", 0, "message", "content").strip
end

# Method to convert text to speech
def text_to_speech(client, text)
  response = client.audio.speech(parameters: {
    model: "tts-1",
    input: text,
    voice: "onyx",
    response_format: "mp3",
    speed: 1.0
  })
  File.binwrite("response.mp3", response)
end

# Method to handle audio stream processing
def process_audio_stream(client)
  Thread.new do
    #whisper_command = "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-base.en.bin -f - -t 4 -c 1"
    whisper_command = "./whisper.cpp/stream -m ./whisper.cpp/models/ggml-#{PodcastBuddy.whisper_model}.bin -t 4 --step 0 --length 5000 --keep 500 --vad-thold 0.60 --audio-ctx 0 --keep-context -c 1"
    PodcastBuddy.logger.info "Buffering audio..."
    Open3.popen3(whisper_command) do |stdin, stdout, stderr, thread|
      stderr_thread = Thread.new do
        stderr.each { |line| PodcastBuddy.whisper_logger.error line }
      end
      stdout_thread = Thread.new do
        stdout.each { |line| PodcastBuddy.whisper_logger.debug line }
      end

      while transcription = stdout.gets
        # Cleanup captured text from whisper
        transcription_text = (transcription.scan(/\[[0-9]+.*[0-9]+\]\s?(.*)\n/) || [p])[0].to_s
        PodcastBuddy.logger.debug "Received transcription: #{transcription_text}"
        transcription_text = transcription_text.gsub("[BLANK_AUDIO]", "")
        transcription_text = transcription_text.gsub(/\A\["\s?/, "")
        transcription_text = transcription_text.gsub(/"\]\Z/, "")
        break if @shutdown_flag

        PodcastBuddy.logger.debug "Filtered: #{transcription_text}"
        next if transcription_text.to_s.strip.squeeze.empty?

        @full_transcription += transcription_text

        if @listening_for_question
          @question_transcription += transcription_text
        else
          @transcription_queue << transcription_text
          PodcastBuddy.update_transcript(transcription_text)
        end
      end

      # Close streams and join stderr thread on shutdown
      stderr_thread.join
      stdout_thread.join
      stdin.close
      stdout.close
      stderr.close
    end
  end
end

# Method to generate show notes
def generate_show_notes(client, transcription)
  summary = extract_topics_and_summarize(client, transcription)
  File.open('show_notes.md', 'w') do |file|
    file.puts "# Show Notes"
    file.puts summary
  end
end

# Periodically summarize latest transcription
def periodic_summarization(client, interval = 15)
  Thread.new do
    loop do
      break if @shutdown_flag

      sleep interval
      latest_transcriptions = []
      latest_transcriptions << @transcription_queue.pop until @transcription_queue.empty?
      unless latest_transcriptions.join.strip.squeeze.empty?
        PodcastBuddy.logger.debug "[periodic summarization] Latest transcript: #{latest_transcriptions.join}"
        summary = extract_topics_and_summarize(client, latest_transcriptions.join)
        File.write(PodcastBuddy.discussion_log_file, summary)
      end
    rescue StandardError => e
      PodcastBuddy.logger.warn "[summarization] periodic summarization failed: #{e.message}"
    end
  end
end

# Handle Ctrl-C to generate show notes
Signal.trap("INT") do
  puts "\nShutting down streams..."
  @shutdown_flag = true
  # Wait for all threads to finish
  @threads.compact.each(&:join)

  puts "\nGenerating show notes..."
  # Will have to re-think this.  Can't syncronize from a trap (Faraday)
  #generate_show_notes(client, @full_transcription)
  exit
end

# Setup signal subscriptions
question_signal.subscribe do
  PodcastBuddy.logger.info "Question signal received"
  @listening_for_question = true
  @question_transcription.clear
end

end_signal.subscribe do
  PodcastBuddy.logger.info "End of question signal received"
  @listening_for_question = false

  PodcastBuddy.logger.info "Waiting for question to log..."
  loop do
    puts "Checking for question..."
    sleep 0.3
    break if @question_transcription.to_s.length > 0 || @listening_for_question = true
  end
  # Guard against interruptions
  if !@question_transcription.empty?
    response_text = answer_question(client, @question_transcription)
    text_to_speech(client, response_text)
    system("afplay response.mp3")
  end
end

# Start audio stream processing
@threads << process_audio_stream(client)
# Start periodic summarization
@threads << periodic_summarization(client, 60)

# Main loop to wait for question and end signals
loop do
  PodcastBuddy.logger.info "Press Enter to signal a question start..."
  gets
  question_signal.trigger
  PodcastBuddy.logger.info "Press Enter to signal the end of the question..."
  gets
  end_signal.trigger
end
