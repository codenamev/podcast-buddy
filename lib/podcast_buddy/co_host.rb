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

          if @listening_for_question_at
            PodcastBuddy.logger.info PodcastBuddy.to_human("🎙️ Listening for question. Press ", :wait) +
              PodcastBuddy.to_human("Enter", :input) +
              PodcastBuddy.to_human(" to signal the end of the question...", :wait)
          else
            PodcastBuddy.logger.info Rainbow("Press ").blue + Rainbow("Enter").black.bg(:yellow) + Rainbow(" to signal a question start...").blue
          end

          wait_for_input
        end
      end
    end

    def stop
      @shutdown = true
    end

    private

    def handle_transcription(data)
      if @listening_for_question_at
        PodcastBuddy.logger.info PodcastBuddy.to_human("Heard Question: #{data[:text]}", :wait)
        @question_buffer << data[:text]
      end
    end

    def start_question
      @listening_for_question_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @listener.suppress_what_you_hear!
      @question_buffer = ""
    end

    def end_question
      PodcastBuddy.logger.info "End of question signal. Generating answer..."
      @listening_for_question_at = nil
      @listener.announce_what_you_hear!
      answer_question(@question_buffer).wait
    end

    def wait_for_input
      input = ""
      loop do
        PodcastBuddy.logger.debug("Shutdown: wait_for_input...") and break if @shutdown
        Timeout.timeout(2) do
          input = gets
          PodcastBuddy.logger.debug("Input received...") if input.include?("\n")
          next unless input.to_s.include?("\n")
          @listening_for_question_at.nil? ? start_question : end_question
          break
        rescue Timeout::Error
          PodcastBuddy.logger.debug("Input timeout...")
          next
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
  end
end
