require 'semantic'
require 'set'
require 'sequel'
require 'socket'

require_relative 'message_parser'
require_relative 'version'

Sequel.extension :migration

module Chatling
  class Server
    def initialize(host: 'localhost', port: 1337, database_path: nil, send_errors: false, polling_interval: 100)
      if database_path.nil? # use in-memory database
        @database = Sequel.sqlite
        Sequel::TimestampMigrator.apply(@database, 'db/migrations')
      else
        @database = Sequel.connect database_path
      end

      @polling_interval = polling_interval
      @send_errors = send_errors

      @server = TCPServer.new(host, port)
      @threads = Set.new
      @client_message_queues = {}
    end

    def run
      loop do
        connection = @server.accept

        _, client_port, _, client_host = connection.peeraddr
        client_identity = "#{client_host}:#{client_port}"
        @client_message_queues[client_identity] = Queue.new

        thread = Thread.start do
          message_parser = MessageParser.new connection
          context = { client_identity: client_identity }
          state = :waiting_for_hello

          begin
            goodbye_message = "Goodbye."

            loop do
              if IO.select([connection], [], [], @polling_interval / 1000).nil?
                until @client_message_queues[client_identity].empty?
                  message_to_send = @client_message_queues[client_identity].pop
                  connection.send(message_to_send.encode, 0)
                end

                next
              end

              message = message_parser.parse!

              case state
              when :waiting_for_hello
                unless message.is_a? MessageKinds::HelloMessage
                  goodbye_message = "Please say hello first."
                  break
                end

                our_version = Semantic::Version.new ::Chatling::VERSION
                their_version = Semantic::Version.new message.version

                unless (our_version.major == their_version.major) and (our_version.minor >= their_version.minor)
                  goodbye_message = "I'm sorry, I can't speak to you."
                  break
                end

                connection.send MessageKinds::HelloMessage.new(version: our_version.to_s, identity: client_identity).encode,
                                0
                state = :in_operation
              when :in_operation
                case message
                when MessageKinds::GoodbyeMessage
                  break
                when MessageKinds::ChatMessage
                  message.populate_from(context) if message.from.nil?
                  @client_message_queues[message.to] << message if @client_message_queues.include? message.to
                  @database[:messages].insert from: message.from, to: message.to, body: message.body
                when MessageKinds::QueryMessage
                  results = message.filters
                                   .reduce(@database[:messages].where(Sequel[to: client_identity] | Sequel[from: client_identity])) { |dataset, filter|
                    filter.apply_to(dataset, context)
                  }.order(Sequel.desc(:id))
                  results = results.map { |row| row.slice(:from, :to, :body) }

                  connection.send MessageKinds::QueryResponseMessage.new(results: results).encode, 0
                else
                  goodbye_message = "You weren't supposed to send me that."
                  break
                end
              end
            end
          rescue => error
            goodbye_message = @send_errors ? error.full_message : "Something went wrong."
            connection.send MessageKinds::GoodbyeMessage.new(message: goodbye_message).encode, 0
          else
            connection.send MessageKinds::GoodbyeMessage.new(message: goodbye_message).encode, 0
          ensure
            connection.close
            @threads.delete thread
          end
        end

        @threads << thread
      end
    end

    def stop(goodbye_message: "Goodbye.", timeout: 10)
      @threads.each(&:kill)
      @server.close
    end
  end
end
