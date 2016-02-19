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

        new_queues = calculate_queue_names
        new_queues = new_queues | config['queues'] if config.has_key?('queues')

        devicedb_ids = new_queues.map { |queue| find_or_create_queue(queue) }
        Hive.devicedb('Device').edit(@identity, { device_queue_ids: devicedb_ids })
        config['queues'] = new_queues
        super
      end

      def calculate_queue_names
        [
            "#{@queue_prefix}#{self.model}",
            "#{@queue_prefix}ios",
            "#{@queue_prefix}ios-#{self.os_version}",
            "#{@queue_prefix}ios-#{self.os_version}-#{self.model}",
            "#{@queue_prefix}#{@device_range}",
            "#{@queue_prefix}#{@device_range}-#{self.os_version}"
        ]
      end

      private

      def find_or_create_queue(name)

        queue = Hive.devicedb('Queue').find_by_name(name)
        return queue.first['id'] unless queue.empty? || queue.is_a?(Hash)

        queue = create_queue(name, "#{name} queue created by Hive Runner")
        queue['id'] unless queue.empty?
      end

      def create_queue(name, description)
        queue_attributes = {
            name: name,
            description: description
        }

        Hive.devicedb('Queue').register(device_queue: queue_attributes )
      end
    end
  end
end