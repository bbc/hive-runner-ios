require 'hive/diagnostic'
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
            #end
            self.fail('Rebooting')
          else
            data[:reboot] = {:value => "Not configured for reboot. Set in config {:reboot_timeout => '2400'}"}
            self.pass("Not configured for reboot", data)
          end
        end

        def repair(result)
          data = {}
          Hive.logger.info("Rebooting the device")
          begin
            data[:last_rebooted] = {:value => Time.now}
            self.pass("Reboot", data)
            self.device_api.reboot
            sleep 5
            60.times do |i|
              Hive.logger.debug("Wait for device #{i}")
              break if DeviceAPI::IOS::Devices.devices.keys.include? self.device_api.serial
              sleep 5
            end
            @last_boot_time = Time.now
          rescue
            Hive.logger.error("Device not found")
          end
          diagnose(data)
        end

      end
    end
  end
end
