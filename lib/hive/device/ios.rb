require 'hive/device'

module Hive
  class Device
    class Ios < Device
      attr_accessor :model, :os_version, :device_type

      def initialize(config)
        @identity = config['id']
        @queue_prefix = config['queue_prefix'].to_s == '' ? '' : "#{config['queue_prefix']}-"
        @model = config['model'].downcase.gsub(/\s/, '_')
        @device_range = config['device_range'].downcase
        @os_version = config['os_version']

        super
      end
    end
  end
end
