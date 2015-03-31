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

        hive_details['devices'].each do |device|
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

        # We will now have a list of devices that haven't previously been added
        devices.each do |device|
          begin
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

        hive_details = Hive.devicedb('Hive').find(Hive.id)
        if hive_details.key?('devices')
          hive_details['devices'].collect do |device|
            Hive.logger.debug("Found iOS device #{device}")
            Object.const_get(@device_class).new(@config.merge(device))
          end
        else
          []
        end
      end
    end
  end
end