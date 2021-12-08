require 'socket'

require_relative 'message_parser'
require_relative 'version'

module Chatling
  class Client
    attr_reader :identity

    def initialize(send_errors: false, polling_interval: 100)
      @inbound_message_queue = Queue.new
      @outbound_message_queue = Queue.new
      @send_errors = send_errors
      @polling_interval = polling_interval
      @thread = nil
      @identity = nil
    end

    def connect(server_host: "localhost", server_port: 1337)
      raise "You are already connected to a server." if self.connected?

      @server_host = server_host
      @server_port = server_port
      @thread = Thread.new do
        connection = nil

        begin
          connection = TCPSocket.new @server_host, @server_port
          message_parser = MessageParser.new connection
          state = :initializing

          loop do
            case state
            when :initializing
              connection.send MessageKinds::HelloMessage.new(version: ::Chatling::VERSION).encode, 0
              message = message_parser.parse!
              unless message.is_a? MessageKinds::HelloMessage
                self.disconnect("Please say hello first.")
              else
                @identity = message.identity
              end
              state = :initialized
            when :initialized
              if @outbound_message_queue.empty?
                unless IO.select([connection], [], [], @polling_interval / 1000).nil?
                  message = message_parser.parse!
                  break if message.is_a? MessageKinds::GoodbyeMessage
                  raise "You weren't supposed to send me that." unless message.is_a? MessageKinds::ChatMessage

                  @inbound_message_queue.push message
                end

                next
              end

              message = @outbound_message_queue.pop
              connection.send message.encode, 0
              if message.is_a? MessageKinds::QueryMessage
                until (response = message_parser.parse!).is_a? MessageKinds::QueryResponseMessage
                  raise "You weren't supposed to send me that." unless response.is_a? MessageKinds::ChatMessage

                  @inbound_message_queue.push response
                end

                @inbound_message_queue.push response
              end
            end
          end
        rescue => error
          goodbye_message = @send_errors ? error.full_message : "Something went wrong."
          connection.send MessageKinds::GoodbyeMessage.new(message: goodbye_message).encode, 0
        ensure
          connection.close unless connection.nil?
        end
      end
    end

    def reconnect(send_errors: false)
      disconnect if connected?
      connect(server_host: @server_host, server_port: @server_port, send_errors: send_errors)
    end

    def disconnect(goodbye_message: "Goodbye.", timeout: 5)
      raise "You aren't connected to a server." if @thread.nil?

      @outbound_message_queue.push MessageKinds::GoodbyeMessage.new(message: goodbye_message)
      @thread.kill unless @thread.join(timeout)

      @thread = nil
      @inbound_message_queue.clear
      @outbound_message_queue.clear
    end

    def connected?
      not @thread.nil?
    end

    def ready?
      not @identity.nil?
    end

    def send_message(message)
      raise "You aren't connected to a server." unless self.connected?

      unless [MessageKinds::ChatMessage, MessageKinds::QueryMessage].include? message.class
        raise ArgumentError.new("You can only send Chat and Query messages. The rest are handled opaquely.")
      end

      @outbound_message_queue.push message
    end

    def receive_message
      raise "You aren't connected to a server." unless self.connected?

      @inbound_message_queue.pop
    end

    def receive_message!
      raise "You aren't connected to a server." unless self.connected?

      @inbound_message_queue.pop unless @inbound_message_queue.empty?
    end

    def say(message, to:)
      send_message MessageKinds::ChatMessage.new(body: message, to: to)
    end

    # TODO - Add a timeout to this in case of malicious / incorrect implementations of the server.
    def query(contains: nil, direction: nil, limit: nil)
      raise "You must specify at least one filter." if [contains, direction, limit].all?(&:nil?)

      unless [:inbound, :outbound, nil].include? direction
        raise "Please specify a valid direction. Valid directions are :inbound and :outbound."
      end

      filters = []
      filters.push(QueryFilters::ContainsFilter.new(fragment: contains)) unless contains.nil?
      filters.push(QueryFilters::LastKMessages.new(k: limit)) unless limit.nil?
      filters.push(QueryFilters::MessageDirection.new(incoming: direction == :inbound)) unless direction.nil?

      send_message MessageKinds::QueryMessage.new(filters: filters.each_with_object({}) { |filter, hash|
        hash[filter.kind] = filter.arguments
      })

      until (response = @inbound_message_queue.pop).is_a? MessageKinds::QueryResponseMessage
        @inbound_message_queue.push response
        sleep @polling_interval / 500
      end

      response.results
    end
  end
end
