require 'hive/worker'
require 'hive/messages/ios_job'

module Hive
  class PortReserver
    attr_accessor :ports
    def initialize
      self.ports = {}
    end

    def reserve(queue_name)
      self.ports[queue_name] = Hive.data_store.port.assign("#{queue_name}")
      self.ports[queue_name]
    end
  end

  class Worker
    class Ios < Worker

      attr_accessor :device

      def initialize(device)
        @ports = PortReserver.new
        self.device = device
        super(device)
      end

      def pre_script(job, file_system, script)
        Hive.devicedb('Device').poll(@options['id'], 'busy')

        FileUtils.mkdir(file_system.home_path + '/build')
        app_path = file_system.home_path + '/build/' + 'build.ipa'
        file_system.fetch_build(job.build, app_path) if job.build

        app_info = DeviceAPI::IOS::Plistutil.get_bundle_id_from_app(app_path)
        app_bundle = app_info['CFBundleIdentifier']

        ip_address = DeviceAPI::IOS::IPAddress.address(self.device['serial'])

        script.set_env 'CHARLES_PROXY_PORT',  @ports.reserve(queue_name: 'Charles')

        # TODO: Allow the scheduler to specify the ports to use

        script.set_env 'APPIUM_PORT',         @ports.reserve(queue_name: 'Appium')
        script.set_env 'BOOTSTRAP_PORT',      @ports.reserve(queue_name: 'Bootstrap')
        script.set_env 'CHROMEDRIVER_PORT',   @ports.reserve(queue_name: 'Chromedriver')

        script.set_env 'APP_PATH', app_path

        script.set_env 'BUNDLE_ID', app_bundle
        script.set_env 'DEVICE_TARGET', self.device['serial']
        script.set_env 'DEVICE_ENDPOINT', "http://#{ip_address}:37265"

        "#{self.device['serial']} #{@ports.ports['Appium']} #{app_path} #{file_system.results_path}"
      end

      def job_message_klass
        Hive::Messages::IosJob
      end

      def post_script(job, file_system, script)
        @log.info('Post script')
        @ports.ports.each do |name, port|
          Hive.data_store.port.release(port)
        end
        Hive.devicedb('Device').poll(@options['id'], 'idle')
      end

      def device_status
        details = Hive.devicedb('Device').find(@options['id'])
        @log.info("Device details: #{details.inspect}")
        details['status']
      end

      def set_device_status(status)
        @log.debug("Setting status of device to '#{status}'")
        details = Hive.devicedb('Device').poll(@options['id'], status)
        details['status']
      end
    end
  end
end