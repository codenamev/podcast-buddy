# Podcast Buddy

This is a simple Ruby command-line tool that allows dropping in an AI buddy to
your podcast.

## Usage

Run your buddy from the command-line:

```bash
ruby podcast_buddy.rb
```

This will install a couple dependencies:

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

1. Your full transcript is stored in `tmp/transcript.log`
2. A summarization of the discussion and topics are stored in `tmp/discussion.log`
3. The raw whisper logs are stored in `tmp/whisper.log`
