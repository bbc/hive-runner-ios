require 'hive/device'

module Hive
  class Device
    class Ios < Device
      def initialize(config)
        @identity = config['id']
        super
      end
    end
  end
end