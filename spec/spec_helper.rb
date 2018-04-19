require "bundler/setup"
require "canvas_qti_to_learnosity_converter"
require 'json'
require 'byebug'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def fixture_path(name)
  path = File.dirname(__FILE__)
  "#{path}/fixtures/#{name}"
end

def read_fixture(name)
  path = File.dirname(__FILE__)
  file = File.new "#{path}/fixtures/#{name}"
  file.read
ensure
  file.close unless file.nil?
end
