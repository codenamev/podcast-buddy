# frozen_string_literal: false

module PodcastBuddy
  # Handles active podcast participation including:
  # - Question detection
  # - Answer generation
  # - Text-to-speech response
  # - Audio playback
  class CoHost
    attr_reader :listener

    def initialize(listener:, audio_service: AudioService.new)
      @listener = listener
      @audio_service = audio_service
      @shutdown = false
      @question_buffer = ""
      @listening_for_question_at = nil
      @notified_input_toggle = false
      @listener.subscribe { |data| handle_transcription(data) }
    end

    def start
      Async do |parent|
        loop do
          PodcastBuddy.logger.debug("Shutdown: wait_for_question...") and break if @shutdown

          PodcastBuddy.logger.info Rainbow("Press ").blue + Rainbow("Enter").black.bg(:yellow) + Rainbow(" to signal a question start...").blue
          wait_for_question_start
          next unless @listening_for_question_at

          PodcastBuddy.logger.info to_human("🎙️ Listening for question. Press ", :wait) + to_human("Enter", :input) + to_human(" to signal the end of the question...", :wait)
          wait_for_question_end
        end
      end
    end

    def stop
      @shutdown = true
    end

    private

    def handle_transcription(data)
      if question_listening_started_before?(data[:started_at])
        PodcastBuddy.logger.info "Heard Question: #{data[:text]}"
        @question_buffer << data[:text]
      end
    end

    def question_listening_started_before?(start)
      @listening_for_question_at && start <= @listening_for_question_at
    end

    def wait_for_question_start
      input = ""
      Timeout.timeout(5) do
        input = gets
        PodcastBuddy.logger.debug("Input received...") if input.include?("\n")
        if input.include?("\n")
          @listening_for_question_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) if @listening_for_question_at.nil?
          @question_buffer = ""
        end
      rescue Timeout::Error
        return
      end
    end

    def wait_for_question_end
      loop do
        PodcastBuddy.logger.debug("Shutdown: wait_for_question_end...") and break if @shutdown

        sleep 0.1 and next if @listening_for_question_at.nil?

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
          PodcastBuddy.logger.info "End of question signal. Generating answer..."
          @listening_for_question_at = nil
          answer_question(@question_buffer).wait
          break
        end
      end
    end

    def answer_question(question)
      Async do
        latest_context = "#{PodcastBuddy.session.current_summary}\nTopics discussed recently:\n---\n#{PodcastBuddy.session.current_topics.split("\n").last(10)}\n---\n"
        previous_discussion = @listener.transcriber.latest(1_000)
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
        @audio_service.text_to_speech(answer, PodcastBuddy.answer_audio_file_path)
        PodcastBuddy.logger.debug("Answer converted to speech: #{PodcastBuddy.answer_audio_file_path}")
        PodcastBuddy.logger.debug("Playing answer...")
        @audio_service.play_audio(PodcastBuddy.answer_audio_file_path)
      end
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
  end
end
