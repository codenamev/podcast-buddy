# frozen_string_literal: false

module PodcastBuddy
  # Handles passive podcast assistance including transcription, summarization,
  # topic extraction, and show notes generation
  class ShowAssistant
    attr_reader :listener

    def initialize(session: PodcastBuddy.session, buddyfile: nil)
      @session = session
      @listener = PodcastBuddy::Listener.new(transcriber: PodcastBuddy::Transcriber.new)
      @shutdown = false
      @listener.subscribe { |data| handle_transcription(data) }
      @current_discussion = ""
      @buddyfile = buddyfile || Buddyfile.load
    end

    def start
      Sync do |task|
        listener_task = task.async { @listener.start }
        summarization_task = task.async { periodic_summarization }

        @tasks = [
          PodcastBuddy::NamedTask.new(name: "Listener", task: listener_task),
          PodcastBuddy::NamedTask.new(name: "Periodic Summarizer", task: summarization_task)
        ]

        task.yield until @shutdown
      end
    end

    def stop
      @shutdown = true
      @listener&.stop
      @tasks&.each do |task|
        PodcastBuddy.logger.info "Waiting for #{task.name} to shutdown..."
        task.task.wait
      end
    end

    def summarize_latest
      return if @current_discussion.empty?

      PodcastBuddy.logger.debug "[periodic summarization] Latest transcript: #{@current_discussion}"
      extract_topics_and_summarize(@current_discussion)
      @current_discussion = ""
    end

    def generate_show_notes
      return if PodcastBuddy.current_transcript.strip.empty?

      response = PodcastBuddy.openai_client.chat(parameters: {
        model: "gpt-4o",
        messages: show_notes_messages,
        max_tokens: 500
      })
      show_notes = response.dig("choices", 0, "message", "content").strip
      File.open(@session.show_notes_path, "w") do |file|
        file.puts show_notes
      end

      PodcastBuddy.logger.info "Show notes saved to: #{@session.show_notes_path}"
    end

    private

    def perform_buddyfile_actions(discussion)
      return if discussion.empty?

      @buddyfile.actions.each do |action|
        action.buffer_text(discussion)
        buffered = action.buffered_text
        next if buffered.empty?

        Async do
          response = PodcastBuddy.openai_client.chat(parameters: action.llm_options.merge(
            messages: action.messages_for(buffered)
          ))
          output = response.dig("choices", 0, "message", "content").strip
          
          File.open(action.output_file, action.output_mode == :append ? "a" : "w") do |f|
            f.puts output
          end

          action.mark_processed!
        rescue => e
          PodcastBuddy.logger.warn "[#{action.name}] action failed: #{e.message}"
        end
      end
    end


    def handle_transcription(data)
      @current_discussion << data[:text]
      perform_buddyfile_actions(data[:text])
    end

    def periodic_summarization(interval = 15)
      Async do
        loop do
          PodcastBuddy.logger.debug("Shutdown: periodic_summarization...") and break if @shutdown

          sleep interval
          summarize_latest
          perform_buddyfile_actions
        rescue => e
          PodcastBuddy.logger.warn "[summarization] periodic summarization failed: #{e.message}"
        end
      end
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

        @session.announce_topics(new_topics)
        @session.add_to_topics(new_topics)
      rescue => e
        PodcastBuddy.logger.error "Failed to update topics: #{e.message}"
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
        PodcastBuddy.logger.info PodcastBuddy.to_human("Thoughts: #{new_summary}", :info)
        @session.update_summary(new_summary)
      rescue => e
        PodcastBuddy.logger.error "Failed to summarize discussion: #{e.message}"
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
