# PodcastBuddy Service Architecture

## Core Services

### ShowAssistant
Handles passive podcast assistance:
- Continuous transcription
- Periodic summarization
- Topic extraction
- Show notes generation
- Custom actions via Buddyfile

### Buddyfile
Configure custom LLM actions to run on transcribed text:
```yaml
actions:
  key_takeaways:
    name: "Key Takeaways"
    interval: 30  # Run every 30 seconds
    llm_options:
      model: "gpt-4"
      messages:
        - role: "system"
          content: "Extract key takeaways from the discussion"
        - role: "user"
          content: "%{discussion}"
    output_file: "takeaways.md"
    mode: append  # or replace
```

### CoHost
Handles active podcast participation:
- Question detection via user input (Enter key)
- Answer generation using GPT-4
- Text-to-speech response using OpenAI TTS
- Audio playback via system audio

## Design Goals
- Each service should be independently runnable
- Services share common resources (Session, Configuration)
- Communication between services via PodSignal
- Clear separation between passive monitoring and active participation
