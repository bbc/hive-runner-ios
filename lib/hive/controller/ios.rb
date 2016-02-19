require 'hive/controller'
require 'hive/worker/ios'
require 'device_api/ios'

module Hive
  class Controller
    class Ios < Controller

      def register_with_devicedb
        devices = DeviceAPI::IOS.devices
        Hive.logger.debug('DDB: No devices attached') if devices.empty?

        hive_details = Hive.devicedb('Hive').find(Hive.id)

        attached_devices = []

        if hive_details.key?('devices')
          @hive_details = hive_details
        else
          hive_details = @hive_details
        end

        if hive_details.is_a? Hash
          hive_details['devices'].select { |a| a['os'] == 'ios'}.each do |device|
            registered_device = devices.select { |a| a.serial == device['serial'] && a.trusted? }
            if registered_device.empty?
              # A previously registered device isn't attached
              Hive.devicedb('Device').hive_disconnect(device['id'])
            else
              Hive.devicedb('Device').poll(device['id'])

              devices = devices - registered_device

              begin
                attached_devices <<
                    self.create_device(device.merge(
                        'os_version' => registered_device[0].version,
                        'model' => device['device_model'],
                        'device_range' => registered_device[0].device_class,
                        'queues' => device['device_queues'].map{ |d| d['name'] },
                        'queue_prefix' => @config['queue_prefix']
                                       ))
              rescue => e
                Hive.logger.warn("Error with connected device: #{e.message}")
              end
            end
          end
          devices.select {|a| a.trusted? }.each do |device|
            register_new_device(device)
          end
        else
          # DeviceDB isn't available, use DeviceAPI instead
          device_info = devices.select { |a| a.trusted? }.map do |device|
            {
                'id' => device.serial,
                'serial' => device.serial,
                'status' => 'idle',
                'model' => device.model,
                'brand' => 'Apple',
                'os_version' => device.version,
                'queue_prefix' => @config['queue_prefix']
            }
          end

          attached_devices = device_info.collect do |physical_device|
            self.create_device(physical_device)
          end
        end
        attached_devices
      end

      def register_with_hivemind
        devices = DeviceAPI::IOS.devices
        Hive.logger.debug('HM: No devices attached') if devices.empty?

        if not Hive.hive_mind.device_details.has_key? :error
          connected_devices = Hive.hive_mind.device_details['connected_devices'].select{ |d| d['device_type'] == 'Mobile' && d['operating_system_name'] == 'ios' }

          to_poll = []
          attached_devices = []
          connected_devices.each do |device|
            Hive.logger.debug("HM: Device details: #{device.inspect}")
            registered_device = devices.select { |a| a.serial == device['serial'] && a.trusted? }
            if registered_device.empty?
              Hive.logger.debug("HM: Removing previously registered device - #{device}")
              Hive.hive_mind.disconnect(device['id'])
            else
              Hive.logger.debug("HM: Device #{device} to be polled")
              begin
                attached_devices << self.created_device(device.merge('os_version' => registered_device[0].version))
                to_poll << device['id']
              rescue => e
                Hive.logger.warn("HM: Error with connected device: #{e.message}")
              end

              devices = devices - registered_device
            end
          end

          Hive.logger.debug("HM: Polling - #{to_poll}")
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
              Hive.logger.info("HM: Device registered: #{dev}")
            rescue => e
              Hive.logger.warn("HM: Error with connected device - #{e.message}")
            end
          end
        else
          Hive.logger.info('HM: No Hive Mind connection')
          device_info = devices.select{|a| a.trusted? }.map do |device|
            {
                'id' => device.serial,
                'serial' => device.serial,
                'status' => 'idle',
                'model' => device.model,
                'brand' => 'Apple',
                'os_version' => device.version,
                'queue_prefix' => @config['queue_prefix']
            }
          end

          attached_devices = device_info.collect do |physical_device|
            self.create_device(physical_device)
          end
        end

        Hive.logger.info(attached_devices)
        attached_devices
      end

      def detect
        register_with_devicedb
        register_with_hivemind
      end

      def display_untrusted
        devices = DeviceAPI::IOS.devices
        untrusted_devices = devices.select { |a| !a.trusted? }

        return if untrusted_devices.empty?
        puts Terminal::Table.new headings: ['Untrusted devices'], rows: [untrusted_devices]
      end

      def register_new_device(device)
        Hive.logger.debug("Adding new iOS device: #{device.model}")

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


    end
  end
end

