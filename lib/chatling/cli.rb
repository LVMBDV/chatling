require_relative "client"
require_relative "server"

module Chatling
  class CLI
    def initialize(arguments)
      begin
        @mode = arguments.shift

        raise ArgumentError.new('Mode must be one of "client" or "server"') unless ["client", "server"].include? @mode

        @host = arguments.shift
        @port = arguments.shift.to_i
        unless (1..25565).include? @port
          puts "Invalid port specified. Reverting back to default port (1337)."
          @port = 1337
        end

        @options = {
        verbose: arguments.include?('-v')
      }
    rescue => error
      print_usage(error.full_message)
      exit 1
    end
  end

  def verbose?
    @options.include? :verbose
  end

  def run
    begin
      if @mode == "client"
        client = Client.new(send_errors: verbose?)
        client.connect(host: @host, port: @port)
        sleep 0.1
        puts "Your identity is '#{client.identity}'." if client.connected?
        while client.connected?
          input = gets.strip

          if input.start_with? "/query"
            arguments = input.split()
            .map { |word| word.split(':', 2) }
            .filter { |pair| pair.size == 2 }
            .to_h
            .slice("contains", "direction", "limit")
            .transform_keys(&:to_sym)

            arguments["limit"] = arguments["limit"].to_i if arguments.include? "limit"
            arguments["direction"] = arguments["direction"].to_sym if arguments.include? "direction"

            puts arguments
            begin
              results = client.query(**arguments)
              if results.empty?
                puts "No results found."
              else
                puts "Results[#{results.size}]:"
                results.each_with_index do |result, index|
                  puts "(#{index + 1}) #{result['from']} -> #{result['to']}: #{result['body']}"
                end
              end
            rescue => error
              puts error.full_message
            end
          elsif input.start_with? "/tell"
            _, recipient, message = input.split(" ", 3)
            client.say message, to: recipient
          elsif input.start_with? "/help"
            puts <<~CMDS
            Available commands:
            /help
            /query [contains:string] [direction:<inbound|outbound>] [limit:int]
            /tell <recipient:string> <message:string>
            CMDS
          end

          until (message = client.receive_message?).nil? do
            puts "#{message.from}:\t#{message.body}"
          end
        end
      else
        server = Server.new(host: @host, port: @port, send_errors: verbose?).run
      end
    rescue => error
      print_usage(error.full_message)
      exit 1
    end
  end

  def print_usage(error_message)
    puts <<~USAGE
    Chatling version #{Chatling::VERSION}
    #{error_message}
    Usage: #{$0} <mode> <host> <port> [options]

    Options:
    -v\tsends verbose information to the console and peer
    USAGE
  end
end
end
