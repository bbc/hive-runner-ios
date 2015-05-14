require 'hive/controller'
require 'hive/worker/ios'
require 'device_api/ios'

module Hive
  class Controller
    class Ios < Controller

      def detect
        Hive.devicedb('Hive').poll(Hive.id)
        devices = DeviceAPI::IOS.devices

        if devices.empty?
          Hive.logger.debug('No devices attached')
          puts 'No devices attached'
        end

        hive_details = Hive.devicedb('Hive').find(Hive.id)

        hive_details['devices'].select {|a| a['os'] == 'ios'}.each do |device|
          registered_device = devices.select { |a| a.serial == device['serial'] }
          if registered_device.empty?
            # A previously registered device isn't attached
            puts "Removing previously registered device - #{device}"
            Hive.devicedb('Device').hive_disconnect(device['id'])
          else
            # A previously registered device is attached, poll it
            puts "Polling attached device - #{device}"
            Hive.devicedb('Device').poll(device['id'])
            devices = devices - registered_device
          end
        end

        untrusted_devices = []
        # We will now have a list of devices that haven't previously been added
        devices.each do |device|
          begin
            if !device.trusted?
              untrusted_devices << device.serial
              next
            end
            puts "Adding new device - #{device}"
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
        end

        if !untrusted_devices.empty?
          untrusted_table = Terminal::Table.new headings: ['Untrusted Devices'], rows: [untrusted_devices]
          puts untrusted_table
        end

        rows = []

        hive_details = Hive.devicedb('Hive').find(Hive.id)
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
        table = Terminal::Table.new :headings => ['Device', 'Serial', 'Queue Name', 'Status'], :rows => rows

        puts table
        if hive_details.key?('devices')
          hive_details['devices'].collect do |device|
            Object.const_get(@device_class).new(@config.merge(device))
          end
        else
          []
        end
      end
    end
  end
end