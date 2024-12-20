# frozen_string_literal: true

module PodcastBuddy
  class Buddyfile
    class Action
      attr_reader :name, :llm_options, :output_file, :output_mode, :interval

      def initialize(name:, llm_options:, output_file:, output_mode: :append, interval: 0)
        @name = name
        @llm_options = llm_options
        @output_file = output_file
        @output_mode = output_mode
        @interval = interval.to_i
        @buffer = ""
        @last_run = Time.now
      end

      def messages_for(discussion)
        llm_options["messages"].map do |message|
          message.merge("content" => format(message["content"], {discussion: discussion}))
        end
      end

      def buffer_text(text)
        @buffer << text
      end

      def ready_to_process?
        return true if interval.zero?
        Time.now - @last_run >= interval
      end

      def buffered_text
        return @buffer if ready_to_process?
        ""
      end

      def mark_processed!
        @last_run = Time.now
        @buffer = ""
      end
    end

    def self.load(path = "Buddyfile")
      return new unless File.exist?(path)

      config = YAML.load_file(path)
      new(actions: parse_actions(config["actions"] || {}))
    end

    def initialize(actions: {})
      @actions = actions
    end

    def actions
      @actions.values
    end

    private

    def self.parse_actions(actions_config)
      actions_config.transform_values do |config|
        Action.new(
          name: config["name"],
          llm_options: config["llm_options"],
          output_file: config["output_file"],
          output_mode: config["mode"]&.to_sym || :append,
          interval: config["interval"]
        )
      end
    end
  end
end
