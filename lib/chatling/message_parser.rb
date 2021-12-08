require_relative 'messages'

module Chatling
  class MessageParser
    def initialize(stream)
      @bencode_stream = BEncode::Parser.new stream
    end

    def parse!
      dictionary = @bencode_stream.parse!
      kind = dictionary.delete('kind')
      Message.build(kind, dictionary.transform_keys(&:to_sym))
    end
  end
end
