  require 'hive/controller'
  require 'hive/worker/ios'
  require 'device_api/ios'

  module Hive
    class Controller
      class Ios < Controller

      def detect
        if Hive.hive_mind.device_details.has_key? :error
          detect_without_hivemind
        else
          detect_with_hivemind
        end
      end

      def detect_with_hivemind
        connected_devices = get_connected_devices
        Hive.logger.debug('No devices attached') if connected_devices.empty?

        # Selecting only ios mobiles
        hivemind_devices = get_hivemind_devices
        to_poll = []
        attached_devices = []

        hivemind_devices.each do |device|
          Hive.logger.debug("Device details: #{device.inspect}")
          begin
            registered_device = connected_devices.select { |a| a.serial == device['serial'] && a.trusted? }
          rescue => e
            registered_device = []
          end

          if registered_device.empty?
            # A previously registered device isn't attached
            Hive.logger.debug("A previously registered device has disappeared: #{device}")
          else
            # A previously registered device is attached, poll it
            Hive.logger.debug("Setting #{device['name']} to be polled")
            Hive.logger.debug("Device: #{registered_device.inspect}")
            begin
              Hive.logger.debug("#{device['name']} OS version: #{registered_device[0].version}")
              # Check OS version and update if necessary
              if device['operating_system_version'] != registered_device[0].version
                Hive.logger.info("Updating OS version of #{device['name']} from #{device['operating_system_version']} to #{registered_device[0].version}")
                Hive.hive_mind.register(
                  id: device['id'],
                   operating_system_name: 'android',
                   operating_system_version: registered_device[0].version
                )
              end
              attached_devices << self.create_device(device.merge(
                                                              'os_version' => registered_device[0].version,
                                                              'device_range' => registered_device[0].device_class
                                                          )
                  )
              to_poll << device['id']
            rescue DeviceAPI::DeviceNotFound => e
               Hive.logger.warn("Device disconnected before registration (serial: #{device['serial']})")
            rescue => e
                Hive.logger.warn("Error with connected device: #{e.message}")
            end

            connected_devices = connected_devices - registered_device
          end
        end

        # Poll already registered devices
        Hive.logger.debug("Polling: #{to_poll}")
        Hive.hive_mind.poll(*to_poll)

        # Register new devices
        if !connected_devices.empty?
          begin
            connected_devices.select{|a| a.trusted? }.each do |device|
              begin
                dev = Hive.hive_mind.register(
                    hostname: device.model,
                    serial: device.serial,
                    macs: [device.wifi_mac_address],
                    brand: 'Apple',
                    model: device.model,
                    device_type: 'Mobile',
                    imei: device.imei,
                    operating_system_name: 'ios',
                    operating_system_version: device.version
                )
                Hive.hive_mind.connect(dev['id'])
                Hive.logger.info("Device registered: #{dev}")
              rescue DeviceAPI::DeviceNotFound => e
                Hive.logger.warn("Device disconnected before registration #{e.message}")
              rescue => e
                Hive.logger.warn("Error with connected device: #{e.message}")
              end
            end
          rescue => e
            Hive.logger.debug("Connected Devices: #{connected_devices}")
            Hive.logger.warn(e)
          end
        end
        Hive.logger.info(attached_devices)
        attached_devices
      end

      def detect_without_hivemind
        connected_devices = get_connected_devices
        Hive.logger.debug('No devices attached') if connected_devices.empty?

        Hive.logger.info('No Hive Mind connection')
        Hive.logger.debug("Error: #{Hive.hive_mind.device_details[:error]}")
        # Hive Mind isn't available, use DeviceAPI instead
        begin
          device_info = devices.select{|a| a.trusted? }.map do |device|
            {
                'id' => device.serial,
                'serial' => device.serial,
                'status' => 'idle',
                'model' => device.model,
                'brand' => 'Apple',
                'os_version' => device.version,
                'device_range' => device.device_class,
                'queue_prefix' => @config['queue_prefix']
            }
          end
          attached_devices = device_info.collect do |physical_device|
            self.create_device(physical_device)
          end
        rescue DeviceAPI::DeviceNotFound => e
          Hive.logger.warn("Device disconnected while fetching device_info #{e.message}")
        rescue => e
          Hive.logger.warn(e)
        end
      
        Hive.logger.info(attached_devices)
        attached_devices
      end

      def get_connected_devices
        devices = DeviceAPI::IOS.devices
        devices.select{|a| a.trusted? }
      end

      def get_hivemind_devices
        begin
          connected_devices = Hive.hive_mind.device_details['connected_devices'].select{ |d| d['device_type'] == 'Mobile' && d['operating_system_name'] == 'ios' }
        rescue NoMethodError
          # Failed to find connected devices
          raise Hive::Controller::DeviceDetectionFailed
        end
      end

      def display_untrusted
        devices = DeviceAPI::IOS.devices
        untrusted_devices = devices.select { |a| !a.trusted? }

        return if untrusted_devices.empty?
        puts Terminal::Table.new headings: ['Untrusted devices'], rows: [untrusted_devices]
      end

    end
  end
end
