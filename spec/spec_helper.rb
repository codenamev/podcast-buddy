# frozen_string_literal: true

require "podcast_buddy"
require "fileutils"

RSpec.configure do |config|
  config.before(:each) do
    # Ensure test directories exist
    FileUtils.mkdir_p(File.join("spec", "fixtures", "tmp", "session"))
  end
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
