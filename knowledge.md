# PodcastBuddy Development Knowledge

## Project Mission
Build a Ruby gem that provides an AI-powered podcast co-host, focusing on clean object-oriented design and separation of concerns.

## Architecture Guidelines

### Core Principles
- Single Responsibility Principle: Each class should have one primary responsibility
- Dependency Injection: Prefer injecting dependencies over hard-coding them
- Configuration over Convention: Make behavior configurable when reasonable
- Test-Driven Development: Write specs first, then implement

### Class Responsibilities
- `PodcastBuddy` module: Configuration and dependency injection only
- `CLI`: Command-line interface and user interaction only
- `Configuration`: Settings and prompt management
- `Session`: Recording session state and file management
- `Listener`: Audio input processing
- `Transcriber`: Text processing and formatting
- `SystemDependency`: External dependency management
- `PodSignal`: Event handling

### Testing
Run tests after changes:
```bash
bundle exec rspec
```

### Style Guide
- Follow Standard Ruby style guide
- Use keyword arguments for methods with multiple parameters
- Prefer composition over inheritance
- Keep methods under 15 lines
- Keep classes under 100 lines

### Current Refactoring Goals
1. Extract audio processing logic from CLI into dedicated service objects
2. Improve separation of concerns between Listener and Transcriber
3. Move transcript/summary management from PodcastBuddy module to Session class
4. Add proper error handling and logging throughout the system
