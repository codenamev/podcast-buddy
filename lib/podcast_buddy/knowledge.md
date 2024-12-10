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
- Question detection
- Answer generation
- Text-to-speech response
- Audio playback

## Design Goals
- Each service should be independently runnable
- Services share common resources (Session, Configuration)
- Communication between services via PodSignal
- Clear separation between passive monitoring and active participation
