require 'hive/diagnostic'
require 'device_api/ios/idevice'

module Hive
  class Diagnostic
    class Ios
      class Uptime < Diagnostic

        def diagnose(data={})
          if config.has_key?(:reboot_timeout)
            if @last_boot_time
              # DeviceAPI iOS doesn't currently supply uptime.
              uptime = (Time.now - @last_boot_time).to_i
              if  uptime < config[:reboot_timeout]
                data[:next_reboot_in] = {:value => "#{config[:reboot_timeout] - uptime}", :unit => "s"}
                self.pass("Time for next reboot: #{config[:reboot_timeout] - uptime}s", data)
              else
                self.fail("Reboot required", data)
              end
            else
              self.fail('No recorded last boot. Rebooting.', data)
            end
            self.fail('Rebooting')
          else
            data[:reboot] = {:value => "Not configured for reboot. Set in config {:reboot_timeout => '2400'}"}
            self.pass("Not configured for reboot", data)
          end
        end

        def repair(result)
          data = {}
          Hive.logger.info('[iOS]') { "Rebooting the device" }
          begin
            data[:last_rebooted] = {:value => Time.now}
            Hive.logger.info('[iOS]') { "Reboot!" }
            self.device_api.reboot
            Hive.logger.info('[iOS]') { "Reboot started" }
            sleep 10
            Hive.logger.info('[iOS]') { "Finished sleeping" }
            60.times do |i|
              Hive.logger.info('[iOS]') { "Wait for device #{i}" }
              Hive.logger.info('[iOS]') { DeviceAPI::IOS::IDevice.devices.keys.join(', ') }
              break if DeviceAPI::IOS::IDevice.devices.keys.include? self.device_api.serial
              sleep 5
            end
            sleep 60
            @last_boot_time = Time.now
            self.pass("Rebooted", data)
          rescue => e
            Hive.logger.error('[iOS]') { "Caught exception #{e}" }
          end
          diagnose(data)
        end

      end
    end
  end
end
