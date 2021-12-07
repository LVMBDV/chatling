require_relative 'messages'

module Chatling
  class MessageParser
    def initialize(stream)
      @bencode_stream = BEncode::Parser.new stream
    end

    def parse!
      dictionary = @bencode_stream.parse!
      Message.build(dictionary)
    end
  end
end
