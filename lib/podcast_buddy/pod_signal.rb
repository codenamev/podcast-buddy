# frozen_string_literal: true

module PodcastBuddy
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
end
