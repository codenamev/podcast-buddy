# frozen_string_literal: true

module PodcastBuddy
  # Represents a prompt for generating content with an LLM
  class Prompt
    # @return [String] system instructions for the LLM
    attr_reader :system_content

    # @return [String] user prompt template
    attr_reader :user_template

    # @param system_content [String] system instructions for the LLM
    # @param user_template [String] user prompt template
    def initialize(system_content:, user_template:)
      @system_content = system_content
      @user_template = user_template
    end

    # Formats the user prompt with given parameters
    # @param params [Hash] parameters to format the user template
    # @return [String] formatted user prompt
    def format_user_prompt(params)
      user_template % params
    end

    # Generates the full prompt for the LLM
    # @param params [Hash] parameters to format the user template
    # @return [Array<Hash>] array of message hashes for the LLM
    def generate(params)
      [
        { role: "system", content: system_content },
        { role: "user", content: format_user_prompt(params) }
      ]
    end
  end
end
