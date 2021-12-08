require "minitest/autorun"

require_relative "../lib/chatling/messages"
require_relative "./helpers"

class TestChat < Minitest::Test
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

  def test_chat
    assert @clients.all?(&:connected?)

    # alice sends a message to bob, bob receives it
    @alice.say "foo", to: @bob.identity
    assert_equal @bob.receive_message,
                 Chatling::MessageKinds::ChatMessage.new(from: @alice.identity, to: @bob.identity, body: "foo")

    # bob sends a message to alice, alice receives it
    @bob.say "bar", to: @alice.identity
    assert_equal @alice.receive_message,
                 Chatling::MessageKinds::ChatMessage.new(from: @bob.identity, to: @alice.identity, body: "bar")

    # chad doesn't get any messages
    assert_nil @chad.receive_message!
  end
end
