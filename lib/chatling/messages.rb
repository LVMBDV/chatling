require "bencode"
require "lucky_case/string"

require_relative "query_filters"

module Chatling
  class Message
    def kind
      self.class.name.split('::').last.chomp("Message").snake_case
    end

    def to_h
      instance_variables.each_with_object({}) do |variable, hash|
        hash[variable.to_s.delete('@')] = instance_variable_get(variable)
      end.compact
    end

    def encode
      hash = self.to_h
      hash['kind'] = self.kind
      hash.bencode
    end

    def self.build(kind, arguments)
      MessageKinds.const_get(kind.pascal_case + 'Message').new(**arguments)
    end
  end

  module MessageKinds
    class WelcomeMessage < Message
      attr_reader :version, :identity

      def initialize(version:, identity:)
        @version = version
        @identity = identity
      end
    end

    class GoodbyeMessage < Message
    end

    class ChatMessage < Message
      attr_reader :from, :to, :body

      def initialize(from:, to:, body:)
        @from = from
        @to = to
        @body = body
      end
    end

    class QueryMessage < Message
      attr_reader :filters

      def initialize(filters:)
        @filters = filters.map { |kind, arguments| QueryFilter.build(kind, arguments) }
      end

      def encode
        hash = { "filters" => @filters.each_with_object({}) { |filter, hash| hash[filter.kind] = filter.arguments } }
        hash['kind'] = self.kind
        hash.bencode
      end
    end

    class QueryResponseMessage < Message
      attr_reader :messages

      def initialize(messages:)
        @messages = messages
      end
    end
  end
end
