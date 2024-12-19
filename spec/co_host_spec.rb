# frozen_string_literal: true

require "spec_helper"

RSpec.describe PodcastBuddy::CoHost do
  let(:listener) { instance_double(PodcastBuddy::Listener, subscribe: nil) }
  let(:audio_service) { instance_double(PodcastBuddy::AudioService) }
  let(:co_host) { described_class.new(listener: listener, audio_service: audio_service) }

  describe "#initialize" do
    it "sets up listener and audio service" do
      expect(co_host.listener).to eq(listener)
    end
  end

  describe "#start" do
    before do
      allow(listener).to receive(:start).and_return(instance_double(Async::Task))
      co_host.instance_variable_set(:@listener, listener)
      allow(PodcastBuddy.logger).to receive(:info)
      allow(PodcastBuddy.logger).to receive(:debug)
    end

    it "starts listening for questions"
  end

  describe "#stop" do
    it "sets shutdown flag" do
      co_host.stop
      expect(co_host.instance_variable_get(:@shutdown)).to be true
    end
  end
end
