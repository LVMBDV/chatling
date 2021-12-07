require "lucky_case/string"
require "sequel"

module Chatling
  class QueryFilter
    def kind
      self.class.name.split('::').snake_case
    end

    def arguments
      instance_variables.each_with_object({}) do |variable, hash|
        hash[variable.to_s.delete('@')] = instance_variable_get(variable)
      end.compact
    end

    def apply(dataset, context)
      raise NotImplementedError.new("You must implement ##{__method__.to_s} for #{self.class.name}.")
    end

    def self.build(kind, arguments)
      QueryFilters.const_get(kind.pascal_case).new(arguments)
    end
  end

  module QueryFilters
    class LastKMessages < QueryFilter
      def initialize(k)
        @k = k
      end

      def apply(dataset, context)
        dataset.limit(@k)
      end
    end

    class MessageContains < QueryFilter
      def initialize(fragment)
        @fragment = fragment
      end

      def apply(dataset, context)
        dataset.where(Sequel.like(:body, "%#{@fragment}%"))
      end
    end

    class MessageDirection < QueryFilter
      def initialize(incoming)
        @incoming = incoming
      end

      def apply(dataset, context)
        column = @incoming ? "to" : "from"
        dataset.where({ column => context.client.identity })
      end
    end
  end
end
