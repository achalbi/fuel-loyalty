ENV["RAILS_ENV"] ||= "test"
ENV["DATABASE_URL"] = ENV.fetch("TEST_DATABASE_URL", "postgresql://postgres:postgres@db:5432/app_test") if ENV["RAILS_ENV"] == "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    host! "www.example.test"
  end
end
