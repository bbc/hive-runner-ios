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

      def alter_project(project_path)
        project = File.read(project_path)

        project = replace_dev_team(project, 'PPH9EJ7977')
        project = replace_code_sign_identity(project, 'iPhone Developer')
        project = replace_provisioning_profile(project, '')

        File.write(project_path, project)
      end

      def replace_project_data(options = {})
        regex = Regexp.new(options[:regex])
        replacements = options[:data].scan(regex).uniq.flatten

        result = options[:data]
        replacements.each do |to_replace|
          result = result.gsub(to_replace, options[:new_value])
        end

        result
      end

      def replace_dev_team(project_data, new_dev_team)
        replace_project_data(regex: '.*DevelopmentTeam = (.*);.*', data: project_data, new_value: new_dev_team )
      end

      def replace_code_sign_identity(project_data, new_identity)
        replace_project_data(regex: '.*CODE_SIGN_IDENTITY.*= "(.*)";.*', data: project_data, new_value: new_identity)
      end

      def replace_provisioning_profile(project_data, new_profile)
        replace_project_data(regex: '.*PROVISIONING_PROFILE = "(.*)";.*', data: project_data, new_value: new_profile)
      end

      def pre_script(job, file_system, script)
        Hive.devicedb('Device').poll(@options['id'], 'busy')

        if job.build
          FileUtils.mkdir(file_system.home_path + '/build')
          app_path = file_system.home_path + '/build/' + 'build.ipa'

          file_system.fetch_build(job.build, app_path)
          app_info = DeviceAPI::IOS::Plistutil.get_bundle_id_from_app(app_path)
          app_bundle = app_info['CFBundleIdentifier']
          script.set_env 'BUNDLE_ID', app_bundle
        else
          # Change the profiles to
          alter_project(file_system.home_path + '/test_code/code/PickNMix/PickNMix.xcodeproj/project.pbxproj')
        end

        ip_address = DeviceAPI::IOS::IPAddress.address(self.device['serial'])

        script.set_env 'CHARLES_PROXY_PORT',  @ports.reserve(queue_name: 'Charles')

        # TODO: Allow the scheduler to specify the ports to use

        script.set_env 'APPIUM_PORT',         @ports.reserve(queue_name: 'Appium')
        script.set_env 'BOOTSTRAP_PORT',      @ports.reserve(queue_name: 'Bootstrap')
        script.set_env 'CHROMEDRIVER_PORT',   @ports.reserve(queue_name: 'Chromedriver')

        script.set_env 'APP_PATH', app_path

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