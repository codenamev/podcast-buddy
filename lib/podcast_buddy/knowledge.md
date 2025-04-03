# PodcastBuddy Service Architecture

## Core Services

### ShowAssistant
Handles passive podcast assistance:
- Continuous transcription
- Periodic summarization
- Topic extraction
- Show notes generation

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
