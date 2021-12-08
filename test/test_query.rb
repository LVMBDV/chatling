require "faker"
require "minitest/autorun"

require_relative "../lib/chatling/messages"
require_relative "./helpers"

class TestQuery < Minitest::Test
  include TestHelpers

  def setup
    create_server
    @alice, @bob, @chad = create_clients 3
    wait_for_clients
  end

  def teardown
    kill_clients
    kill_server
  end

  def test_limit_query
    assert @clients.all?(&:connected?)

    phrases = 20.times.map { Faker::Lorem.unique.sentence }

    phrases.each_with_index do |phrase, index|
      if index % 2 == 0
        sender = @alice
        receiver = @bob
      else
        sender = @bob
        receiver = @alice
      end

      sender.say phrase, to: receiver.identity

      # Order gets out of whack if the messages are blazing fast.
      # The same happens in IRC as well.
      sleep 0.001
    end

    results = @alice.query limit: 10
    assert results.size == 10
    results.map { |result| result["body"] }.zip(phrases.reverse.first(results.length)).each do |pair|
      assert_equal *pair
    end
  end
end
