require "byebug"

require_relative '../lib/chatling/client'
require_relative '../lib/chatling/server'

module TestHelpers
  def create_client
    @clients ||= []
    client = Chatling::Client.new(send_errors: true)
    client.connect
    @clients.push(client)
    client
  end

  def create_clients(number)
    number.times.map do
      create_client
    end.to_a
  end

  def create_server
    @server = Chatling::Server.new(send_errors: true)
    @server_thread = Thread.new do
      @server.run
    end
  end

  def wait_for_clients(polling_interval: 0.1)
    sleep(polling_interval) until @clients.all?(&:ready?)
  end

  def kill_server
    @server_thread.kill
    @server.stop
  end

  def kill_clients
    @clients.each(&:disconnect)
  end
end
