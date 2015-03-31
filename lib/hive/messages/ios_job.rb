require 'hive/messages'

module Hive
  module Messages
    class IosJob < Hive::Messages::Job
      def build
        self.target.symbolize_keys[:build]
      end
    end
  end
end