ENV["RAILS_ENV"] ||= "test"

# Set Docker-friendly database defaults if running in Docker
# Check if we're in Docker by looking for Docker-specific files or env vars
if ENV["DB_HOST"].nil? && ENV["DATABASE_URL"].nil?
  # Check if we're in Docker (common indicators)
  in_docker = File.exist?("/.dockerenv") || 
              File.exist?("/proc/self/cgroup") && File.read("/proc/self/cgroup").include?("docker")
  
  if in_docker
    ENV["DB_HOST"] = "db"
    ENV["DB_PASSWORD"] = "password" if ENV["DB_PASSWORD"].nil?
  end
end

require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
