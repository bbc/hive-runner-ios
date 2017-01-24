require 'hive/messages'

module Hive
  module Messages
    class IosJob < Hive::Messages::Job
      def build
        self.target.symbolize_keys[:build]
      end

      def resign
        self.target.symbolize_keys[:resign].to_i != 0
      end
    end
  end
end
