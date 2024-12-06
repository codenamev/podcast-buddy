# Podcast Buddy

This is a simple Ruby command-line tool that allows dropping in an AI buddy to
your podcast.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add podcast-buddy

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install podcast-buddy

## Usage

Run your buddy from the command-line:

```bash
podcast-buddy
```

This will install a couple dependencies, if they don't exist:

1. `git` (for cloning whisper.cpp locally)
2. `sdl2` - Simple DirectMedia Layer; for cross-platform audio input access
3. [whipser.cpp with streaming](https://github.com/ggerganov/whisper.cpp/tree/master/examples/stream) – For transcribing audio in near-real-time

Other requirements:

1. OpenAI token stored in your environment as `OPENAI_ACCESS_TOKEN`
2. MacOS

### Asking your buddy questions during recordings

At any time, you can press the `return` key and ask your buddy a question.
Once you see the question show up in the output, press `return` key again and
your Buddy will answer using the system output (via `afplay`).

### Completing your pod

Once you're done, simply `ctrl-c` to wrap things up.

### Session Files

Each session directory contains:

1. `transcript.log` - Full transcript of the discussion
2. `summary.log` - Summarization of the discussion
3. `topics.log` - List of topics extracted from the discussion
4. `show-notes.md` - Generated show notes in markdown format
5. `whisper.log` - Raw whisper transcription logs
6. `response.mp3` - Latest AI response audio file

### Options

**debug mode**: `podcast-buddy --debug` – shows verbose logging
**custom whisper model**: `podcast-buddy --whisper base.en` – use any of [these available models](https://github.com/ggerganov/whisper.cpp/blob/master/models/download-ggml-model.sh#L28-L49).
**custom session**: `podcast-buddy --name "Ruby Rogues 08-15-2024"` – saves files to a new `tmp/Ruby Rogues 08-15-2024/` directory.

Note: Both `podcast-buddy` and `podcast_buddy` commands are available and work identically.

### Configuration

Configure PodcastBuddy globally:

```ruby
PodcastBuddy.configure do |config|
  config.whisper_model = "base.en"  # Choose whisper model
  config.root = "path/to/files"     # Set root directory for files
  config.logger = Logger.new($stdout, level: Logger::DEBUG)
  config.openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"]) # Optional: custom OpenAI client
end
```

### Sessions

PodcastBuddy organizes recordings into sessions. Each session has its own directory containing all related files.

To start a named session:

```bash
podcast-buddy --name "My Awesome Podcast Episode 1"
```

This creates a new directory at `tmp/My Awesome Podcast Episode 1/` containing all session files.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codenamev/podcast-buddy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codenamev/podcast-buddy/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PodcastBuddy project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codenamev/podcast-buddy/blob/main/CODE_OF_CONDUCT.md).
