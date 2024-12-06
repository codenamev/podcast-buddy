## [Unreleased]

* Refactored CLI into a dedicated class for improved maintainability
* Moved AI prompts into configurable options
* Added `podcast-buddy` executable as an alternative to `podcast_buddy`

* Renamed `show_notes_log` to `show_notes_path` for clarity and consistency
* Introduced `PodcastBuddy::Session` abstraction
* Added `PodcastBuddy::Configuration` for global settings
* Fixed test directory structure and improved test stability

## [0.2.1] - 2024-08-13

* Fixes typo in command-line help banner to reference proper podcast_buddy command
* Updates README with new options

## [0.2.0] - 2024-08-13

* [9edc409](https://github.com/codenamev/podcast-buddy/commit/9edc409) - Refactor to make use of Async
  * Now properly generates show notes on exit
* [7d8db13](https://github.com/codenamev/podcast-buddy/commit/7d8db13) - Update show notes prompt to cite sources
* [c3ef97d](https://github.com/codenamev/podcast-buddy/commit/c3ef97d) - Allow configuring the whisper model to use
* [e7cb278](https://github.com/codenamev/podcast-buddy/commit/e7cb278) - Adds session naming to store files in specific directories
* [39e9e78](https://github.com/codenamev/podcast-buddy/commit/39e9e78) - Overwrite summary on every periodic update
* [0518b56](https://github.com/codenamev/podcast-buddy/commit/0518b56) - Update topic extraction prompt to fix 'Empty response' topics
* [b72ba8f](https://github.com/codenamev/podcast-buddy/commit/b72ba8f) - Use brew list -1 to /dev/null to quiet initial outputs when already setup
* [98a2484](https://github.com/codenamev/podcast-buddy/commit/98a2484) - Remove no longer needed commented code in Signal.trap now that we're Ansync
* [62cf6ea](https://github.com/codenamev/podcast-buddy/commit/62cf6ea) - Update periodic summarize/topic calls to use new PodcastBuddy.current_transcript method, and update other current_* methods to re-use the memoized versions


## [0.1.1] - 2024-08-09

- Fixes typo in topic extraction prompt ([7e07e](https://github.com/codenamev/podcast-buddy/commit/7e07e307135c95cb4bb68dadc354f0b2519c7721))

## [0.1.0] - 2024-08-09

- Initial release
