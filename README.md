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

### Helpful files logged during your session with Buddy

1. Your full transcript is stored in `tmp/transcript-%Y-%m-%d.log`.
2. A summarization of the discussion is stored in `tmp/summary-%Y-%m-%d.log`.
3. A list of topics extracted from the discussion is stored in `tmp/topics-%Y-%m-%d.log`.
4. The Show Notes are stored in `tmp/show-notes-%Y-%m-%d.log`.
5. The raw whisper logs are stored in `tmp/whisper.log`.

### Options

**debug mode**: `podcast_buddy --debug` – shows verbose logging
**custom whisper model**: `podcast_buddy --whisper base.en` – use any of [these available models](https://github.com/ggerganov/whisper.cpp/blob/master/models/download-ggml-model.sh#L28-L49).
**custom session**: `podcast_buddy --name "Ruby Rogues 08-15-2024"` – saves files to a new `tmp/Ruby Rogues 08-15-2024/` directory.

### Configuration

Configure PodcastBuddy globally:

```ruby
PodcastBuddy.configure do |config|
  config.whisper_model = "base.en"  # Choose whisper model
  config.root = "path/to/files"     # Set root directory for files
  config.logger = Logger.new($stdout, level: Logger::DEBUG)
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codenamev/podcast-buddy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codenamev/podcast-buddy/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PodcastBuddy project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codenamev/podcast-buddy/blob/main/CODE_OF_CONDUCT.md).
