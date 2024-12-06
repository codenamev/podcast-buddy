require "spec_helper"
require "podcast_buddy"

def reset_session!
  session_path = File.join("spec", "fixtures", "tmp", "session")
  FileUtils.mkdir_p(session_path)
  File.write(File.join(session_path, "summary.log"), "Existing summary")
  File.write(File.join(session_path, "transcript.log"), "Existing transcript")
  File.write(File.join(session_path, "topics.log"), "Existing topics")
  PodcastBuddy.logger = nil
  PodcastBuddy.configure do |config|
    config.root = File.join("spec", "fixtures")
  end
  PodcastBuddy.start_session(name: "session")
end

RSpec.describe PodcastBuddy do
  let(:config) { PodcastBuddy.config }
  let(:session) { PodcastBuddy.session }

  before { reset_session! }

  describe ".config" do
    it "returns a Configuration instance" do
      expect(PodcastBuddy.config).to be_a(PodcastBuddy::Configuration)
    end

    it "memoizes the configuration" do
      expect(PodcastBuddy.config).to eq(PodcastBuddy.config)
    end
  end

  describe ".configure" do
    it "yields the configuration if a block is given" do
      expect { |b| PodcastBuddy.configure(&b) }.to yield_with_args(PodcastBuddy::Configuration)
    end

    it "creates a new configuration instance" do
      old_config = PodcastBuddy.config
      PodcastBuddy.configure
      expect(PodcastBuddy.config).not_to eq(old_config)
    end
  end

  describe ".start_session" do
    it "creates a new session with the given name" do
      expect(PodcastBuddy::Session).to receive(:new).with(name: "test_session")
      PodcastBuddy.start_session(name: "test_session")
    end
  end

  describe ".setup" do
    before do
      allow(PodcastBuddy::SystemDependency).to receive(:auto_install!)
      allow(PodcastBuddy::SystemDependency).to receive(:resolve_whisper_model)
    end

    it "installs required system dependencies" do
      expect(PodcastBuddy::SystemDependency).to receive(:auto_install!).with(:git)
      expect(PodcastBuddy::SystemDependency).to receive(:auto_install!).with(:sdl2)
      expect(PodcastBuddy::SystemDependency).to receive(:auto_install!).with(:whisper)
      expect(PodcastBuddy::SystemDependency).to receive(:auto_install!).with(:bat)
      PodcastBuddy.setup
    end

    it "resolves the whisper model" do
      expect(PodcastBuddy::SystemDependency).to receive(:resolve_whisper_model).with(PodcastBuddy.whisper_model)
      PodcastBuddy.setup
    end
  end

  describe ".root" do
    it "returns the current working directory" do
      expect(PodcastBuddy.root).to eq(Dir.pwd)
    end
  end

  describe ".session=" do
    it "creates a new session with the given name" do
      expect(PodcastBuddy::Session).to receive(:new).with(name: "new_session")
      PodcastBuddy.session = "new_session"
    end
  end

  describe ".session" do
    it "returns the current session" do
      expect(PodcastBuddy.session).to be_a(PodcastBuddy::Session)
    end

    it "creates a new session if none exists" do
      PodcastBuddy.instance_variable_set(:@session, nil)
      expect(PodcastBuddy::Session).to receive(:new)
      PodcastBuddy.session
    end
  end

  describe ".logger" do
    it "returns a logger instance" do
      expect(PodcastBuddy.logger).to be_instance_of(Logger)
    end
  end

  describe ".logger=" do
    it "sets the logger" do
      new_logger = instance_double(Logger)
      PodcastBuddy.logger = new_logger
      expect(PodcastBuddy.logger).to eq(new_logger)
    end
  end

  describe ".whisper_model" do
    it "returns the whisper model from the configuration" do
      expect(config).to receive(:whisper_model)
      PodcastBuddy.whisper_model
    end
  end

  describe ".whisper_command" do
    it "returns the whisper command from the configuration" do
      expect(config).to receive(:whisper_command)
      PodcastBuddy.whisper_command
    end
  end

  describe ".whisper_logger=" do
    it "creates a new logger with the given file path" do
      PodcastBuddy.instance_variable_set(:@whisper_logger, nil)
      expect(Logger).to receive(:new).with("whisper.log", "daily", level: Logger::DEBUG)
      PodcastBuddy.whisper_logger = "whisper.log"
    end
  end

  describe ".whisper_logger" do
    it "creates a new logger with the session whisper log" do
      PodcastBuddy.instance_variable_set(:@whisper_logger, nil)
      expect(Logger).to receive(:new).with(session.whisper_log, "daily", level: Logger::DEBUG)
      PodcastBuddy.whisper_logger
    end
  end

  describe ".current_transcript" do
    context "when transcript file exists" do
      it "returns the content of the transcript file" do
        expect(PodcastBuddy.current_transcript).to eq("Existing transcript")
      end
    end

    context "when transcript file does not exist" do
      before { allow(File).to receive(:exist?).with(session.transcript_log).and_return(false) }
      it "returns an empty string" do
        expect(PodcastBuddy.current_transcript).to eq("")
      end
    end
  end

  describe ".update_transcript" do
    before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }
    after { File.write(session.transcript_log, "Existing transcript") }

    it "appends the text to the transcript file" do
      expect(File).to receive(:open).with(session.transcript_log, "a")
      PodcastBuddy.update_transcript("New text")
    end

    it "updates the current transcript" do
      PodcastBuddy.update_transcript("New text")
      expect(PodcastBuddy.current_transcript).to include("New text")
    end
  end

  describe ".current_summary" do
    context "when summary file exists" do
      before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }

      it "returns the content of the summary file" do
        expect(PodcastBuddy.current_summary).to eq("Existing summary")
      end
    end

    context "when summary file does not exist" do
      it "returns an empty string" do
        allow(File).to receive(:exist?).with(session.summary_log).and_return(false)
        expect(PodcastBuddy.current_summary).to eq("")
      end
    end
  end

  describe ".update_summary" do
    before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }
    after { File.write(session.summary_log, "Existing summary") }

    it "updates the current summary" do
      PodcastBuddy.update_summary("New summary")
      expect(PodcastBuddy.current_summary).to eq("New summary")
    end
  end

  describe ".current_topics" do
    context "when topics file exists" do
      before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }

      it "returns the content of the topics file" do
        expect(PodcastBuddy.current_topics).to eq("Existing topics")
      end
    end

    context "when topics file does not exist" do
      it "returns an empty string" do
        allow(File).to receive(:exist?).with(session.topics_log).and_return(false)
        expect(PodcastBuddy.current_topics).to eq("")
      end
    end
  end

  describe ".add_to_topics" do
    before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }
    after { File.write(session.topics_log, "Existing topics") }

    it "appends the topics to the topics file" do
      PodcastBuddy.add_to_topics("New topics")
      expect(PodcastBuddy.current_topics).to include("Existing topics", "New topics")
    end

    it "updates the current topics" do
      PodcastBuddy.add_to_topics("New topics")
      expect(PodcastBuddy.current_topics).to include("New topics")
    end
  end

  describe ".announce_topics" do
    before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }
    it "writes the topics to the topics file" do
      expect(File).to receive(:write).with(session.topics_log, "Announced topics")
      allow(PodcastBuddy).to receive(:system)
      PodcastBuddy.announce_topics("Announced topics")
    end

    it "displays the topics using bat" do
      allow(File).to receive(:write)
      expect(PodcastBuddy).to receive(:system).with("bat", session.topics_log, "--language=markdown")
      PodcastBuddy.announce_topics("Announced topics")
    end
  end

  describe ".answer_audio_file_path" do
    before { allow(session).to receive(:base_path).and_return(File.join("fixtures", "session")) }
    it "returns the answer audio file path from the session" do
      expect(PodcastBuddy.answer_audio_file_path).to eq(session.answer_audio_file)
    end
  end
end
