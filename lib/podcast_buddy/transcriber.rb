module PodcastBuddy
  # Manages the transcript of the podcast
  class Transcriber
    # @return [String] full transcript of the podcast
    attr_reader :full_transcript

    def initialize
      @full_transcript = ""
      @last_timestamp = 0
    end

    # Process new transcription text
    # @param line [String] raw transcription line from whisper
    # @return [String] cleaned transcription text
    def process(line)
      timestamp, text = parse_line(line)
      # With VAD, timestamps are irrelevant.  Leaving here in case we want to
      # reconsider
      if !text.empty?# && timestamp && (timestamp.zero? || timestamp > @last_timestamp)
        @full_transcript += text
        @last_timestamp = timestamp
      end
      text
    end

    # Get the latest portion of the transcript
    # @param limit [Integer] number of characters to return
    # @return [String] latest portion of the transcript
    def latest(limit = 200)
      @full_transcript[[@full_transcript.length - limit, 0].max, limit] || raise(ArgumentError, "negative limit")
    end

    private

    def parse_line(line)
      timestamp, text = nil, ""
      match = line.match(/\[.*?(\d{2}:\d{2}:\d{2}\.\d{3}).*?\]\s{1,3}(.+)/)
      timestamp, text = [match[1].to_i, match[2]] if match
      text.gsub!(/(\[BLANK_AUDIO\]|\A\["\s?|"\]\Z)/, "")&.strip
      text.concat(" ") if text.match?(/[^\w\s]\Z/)
      [timestamp, text]
    end

    # Timestamps are formatted as 'h:m:s'
    def time_to_seconds(time_str)
      h, m, s = time_str.split(":").map(&:to_f)
      (h * 3600) + (m * 60) + s
    end
  end
end
