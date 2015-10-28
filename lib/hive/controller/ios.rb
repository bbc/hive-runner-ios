require 'hive/controller'
require 'hive/worker/ios'
require 'device_api/ios'

module Hive
  class Controller
    class Ios < Controller

      def devicedb_register(details)
        registered_device = details.select { |a| a.serial == device['serial'] }
        if registered_device.empty?
          # A previously registered device isn't attached
          Hive.logger.debug("Removing previously registered device - #{device}")
          Hive.devicedb('Device').hive_disconnect(device['id'])
          []
        else
          # A previously registered device is attached, poll it
          Hive.logger.debug("#{Time.now} Polling attached device - #{device}")
          Hive.devicedb('Device').poll(device['id'])
          Hive.logger.debug("#{Time.now} Finished polling device - #{device}")

          populate_queues(device)
          registered_device
        end
      end

      def detect
        devices = DeviceAPI::IOS.devices
        Hive.logger.debug('No devices attached') if devices.empty?

        hive_details = Hive.devicedb('Hive').find(Hive.id)

        # Cache the last copy of the data returned from DeviceDB in case it becomes unavailable
        if hive_details.key?('devices')
          hive_details = @hive_details
        else
          @hive_details = hive_details
        end

        if hive_details.is_a? Hash
          hive_details['details'].select { |a| a['os'] == 'ios' }.each do |device|
            devices = devices - devicedb_register(device)
          end
        else
          # DeviceDB is unavailable,
        end

        display_untrusted(devices)
        display_devices

        if hive_details.key?('devices')
          hive_details['devices'].select {|a| a['os'] == 'ios'}.collect do |device|
            object = Object
            @device_class.split('::').each { |sub| object = object.const_get(sub) }
            object.new(@config.merge(device))
          end
        else
          []
        end
      end

      def display_untrusted(devices)
        untrusted_devices = []
        # We will now have a list of devices that haven't previously been added
        devices.each do |device|
          begin
            if !device.trusted?
              untrusted_devices << device.serial
              next
            end

            register_new_device(device)
          end
        end

        if !untrusted_devices.empty?
          puts Terminal::Table.new headings: ['Untrusted Devices'], rows: [untrusted_devices]
        end
      end

      def display_devices
        rows = []

        hive_details = Hive.devicedb('Hive').find(Hive.id)
        if hive_details.key?('devices')
          unless hive_details['devices'].empty?
            rows = hive_details['devices'].map do |device|
              [
                  "#{device['device_brand']} #{device['device_model']}",
                  device['serial'],
                  (device['device_queues'].map { |queue| queue['name']}).join("\n"),
                  device['status']
              ]
            end
          end
        end
        table = Terminal::Table.new :headings => ['Device', 'Serial', 'Queue Name', 'Status'], :rows => rows

        puts(table)
      end

      def register_new_device(device)
        Hive.logger.debug("Found iOS device: #{device.model}")

        attributes = {
            os:           'ios',
            os_version:   device.version,
            serial:       device.serial,
            device_type:  'mobile',
            device_model: device.model.to_s.gsub(',','_'),
            device_range: device.device_class,
            device_brand: 'Apple',
            hive:         Hive.id
        }

        registration = Hive.devicedb('Device').register(attributes)
        Hive.devicedb('Device').hive_connect(registration['id'], Hive.id)
      end

      def populate_queues(device)
        queues = calculate_queue_names(device)

        devicedb_queues = device['device_queues'].map { |d| d['name'] }
        # Check to see if the queues have already been registered with this device
        missing_queues = (queues - devicedb_queues) + (devicedb_queues - queues)
        return if missing_queues.empty?

        queues << missing_queues

        queue_ids = queues.flatten.uniq.map { |queue| find_or_create_queue(queue) }

        values = {
            name: device['name'],
            hive_id: device['hive_id'],
            feature_list: device['features'],
            device_queue_ids: queue_ids
        }

        Hive.devicedb('Device').edit(device['id'], values)
      end

      def find_or_create_queue(name)
        queue = Hive.devicedb('Queue').find_by_name(name)
        return queue.first['id'] unless queue.empty?

        create_queue(name, "#{name} queue created by Hive Runner")['id']
      end

      def create_queue(name, description)
        queue_attributes = {
            name: name,
            description: description
        }

        Hive.devicedb('Queue').register(device_queue: queue_attributes )
      end

      def calculate_queue_names(device)

        queues = [
            device['device_model'],
            device['os'],
            "#{device['os']}-#{device['os_version']}",
            "#{device['os']}-#{device['os_version']}-#{device['device_model']}",
            device['device_type'],
            "#{device['os']}-#{device['device_type']}"
        ]

        queues << device["features"] unless device["features"].empty?

        queues.flatten
      end
    end
  end
end