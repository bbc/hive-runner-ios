require 'hive/controller'
require 'hive/worker/ios'
require 'device_api/ios'

module Hive
  class Controller
    class Ios < Controller

      def detect
        devices = DeviceAPI::IOS.devices
        Hive.logger.debug('No devices attached') if devices.empty?

        if not Hive.hive_mind.device_details.has_key? :error
          begin
            connected_devices = Hive.hive_mind.device_details['connected_devices'].select{ |d| d['device_type'] == 'Mobile' && d['operating_system_name'] == 'ios' }
          rescue NoMethodError
            # Failed to find connected devices
            raise Hive::Controller::DeviceDetectionFailed
          end

          to_poll = []
          attached_devices = []
          connected_devices.each do |device|
            Hive.logger.debug("Device details: #{device.inspect}")
            registered_device = devices.select { |a| a.serial == device['serial'] && a.trusted? }
            if registered_device.empty?
              Hive.logger.debug("Removing previously registered device - #{device}")
            else
              Hive.logger.debug("Device #{device} to be polled")
              begin
                attached_devices << self.create_device(device.merge(
                                                           'os_version' => registered_device[0].version,
                                                           'device_range' => registered_device[0].device_class
                                                       )
                )
                to_poll << device['id']
              rescue => e
                Hive.logger.warn("Error with connected device: #{e.message}")
              end

              devices = devices - registered_device
            end
          end

          Hive.logger.debug("Polling - #{to_poll}")
          Hive.hive_mind.poll(*to_poll)

          devices.select{|a| a.trusted? }.each do |device|
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
            rescue => e
              Hive.logger.warn("Error with connected device - #{e.message}")
            end
          end
        else
          Hive.logger.info('No Hive Mind connection')
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
            begin
              self.create_device(physical_device)
            rescue => e
              Hive.logger.info("Could not create device: #{physical_device}");
            end
          end
        end

        Hive.logger.info(attached_devices)
        attached_devices
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

