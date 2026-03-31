ENV["RAILS_ENV"] ||= "test"
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

# Helper for signing in during integration tests
module SignInHelper
  def sign_in_as(user)
    session = user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Test Agent"
    )
    # Use post to actually sign in through the session controller
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
