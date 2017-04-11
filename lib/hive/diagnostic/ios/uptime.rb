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
          else
            data[:reboot] = {:value => "Not configured for reboot. Set in config {:reboot_timeout => '2400'}"}
            self.pass("Not configured for reboot", data)
          end
        end

        def repair(result)
          data = {}
          Hive.logger.debug('[iOS]') { "Rebooting #{self.device_api.serial}" }
          begin
            data[:last_rebooted] = {:value => Time.now}
            self.device_api.reboot
            sleep 10
            60.times do |i|
              Hive.logger.debug('[iOS]') { "Wait for #{self.device_api.serial} (#{i})" }
              break if DeviceAPI::IOS::IDevice.devices.keys.include? self.device_api.serial
              sleep 5
            end
            @last_boot_time = Time.now
            self.pass("Rebooted", data)
          rescue => e
            Hive.logger.error('[iOS]') { "Caught exception #{e} while rebooting #{self.device_api.serial}" }
          end
          diagnose(data)
        end

      end
    end
  end
end
