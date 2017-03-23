require 'hive/worker'
require 'hive/messages/ios_job'
require 'fruity_builder'

module Hive
  class PortReserver
    attr_accessor :ports
    def initialize
      self.ports = {}
    end

    def reserve(queue_name)
      self.ports[queue_name] = yield
      self.ports[queue_name]
    end
  end

  class Worker
    class Ios < Worker

      attr_accessor :device

      def initialize(device)
        @serial = device['serial']
        @queue_prefix = device['queue_prefix'].to_s == '' ? '' : "#{device['queue_prefix']}-"
        @model = device['model'].downcase.gsub(/\s/, '_')
        @device_range = device['device_range'].downcase
        @os_version = device['os_version']
        @worker_ports = PortReserver.new
        set_device_status('happy')
        self.device = device
        super(device)
      end

      def alter_project(project_path)
        dev_team              = @options['development_team']      || ''
        signing_identity      = @options['signing_identity']      || ''
        provisioning_profile  = @options['provisioning_profile']  || ''

        helper = FruityBuilder::IOS::Helper.new(project_path)

        # Check to see if a project has been passed in
        return unless helper.has_project?

        @log.debug("Resign: #{job.resign}")
        if job.resign
          @log.debug("Resign: Changing bundle id to #{@options['bundle_id']}")
          helper.build.replace_bundle_id(@options['bundle_id'])

          @log.debug("Resign: Changing dev team to #{dev_team}")
          helper.build.replace_dev_team(dev_team)
          @log.debug("Resign: Changing signing identity to #{signing_identity}")
          helper.build.replace_code_sign_identity(signing_identity)
          @log.debug("Resign: Changing provisioning profile to #{provisioning_profile}")
          helper.build.replace_provisioning_profile(provisioning_profile)
          helper.build.save_project_properties
          @log.debug("Finished resigning")
        end
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

      def pre_script(job, file_system, script)

        set_device_status('busy')
        device = DeviceAPI::IOS.device(self.device['serial'])
        @installed_apps = device.list_installed_packages
        @installed_apps.each_pair do |app, details|
          @log.info("Pre-installed app: #{app}")
          details.each_pair do |k, v|
            @log.debug("  #{k}: #{v}")
          end
        end

        if job.build
          FileUtils.mkdir(file_system.home_path + '/build')
          app_path = file_system.home_path + '/build/' + 'build.ipa'

          file_system.fetch_build(job.build, app_path)
          @log.debug("Resign: #{job.resign}")
          if job.resign
            entitlements = FruityBuilder::IOS::Signing.enable_get_tasks(app_path)
            FruityBuilder::IOS::Signing.sign_app({ cert: @options['signing_identity'], entitlements: entitlements, app: app_path } )
            app_info = FruityBuilder::IOS::Plistutil.get_bundle_id_from_app(app_path)
            app_bundle = app_info['CFBundleIdentifier']
            device.install(app_path) if job.install_build
            script.set_env 'BUNDLE_ID', app_bundle
          end
        else
          alter_project(file_system.home_path + '/test_code/code/')
        end

        ip_address = DeviceAPI::IOS::IPAddress.address(self.device['serial'])

        if ip_address.nil?
          # There is a bug in the IPAddress app that stopping the IP address from being
          # returned when it's first run, however it works the second time around.
          # This is a *temporary* fix until that issue can be resolved.
          ip_address = DeviceAPI::IOS::IPAddress.address(self.device['serial'])
        end
        script.set_env 'CHARLES_PROXY_PORT',  @worker_ports.reserve(queue_name: 'Charles') { @port_allocator.allocate_port }

        # TODO: Allow the scheduler to specify the ports to use

        script.set_env 'APPIUM_PORT',         @worker_ports.reserve(queue_name: 'Appium') { @port_allocator.allocate_port }
        script.set_env 'BOOTSTRAP_PORT',      @worker_ports.reserve(queue_name: 'Bootstrap') { @port_allocator.allocate_port }
        script.set_env 'CHROMEDRIVER_PORT',   @worker_ports.reserve(queue_name: 'Chromedriver') { @port_allocator.allocate_port }

        script.set_env 'APP_PATH', app_path
        script.set_env 'APP_BUNDLE_PATH', app_path
        script.set_env 'DEVICE_TARGET', self.device['serial']

        # Required for Calabash testing
        script.set_env 'DEVICE_ENDPOINT', "http://#{ip_address}:37265" unless ip_address.nil?

        # Required for Appium testing
        script.set_env 'DEVICE_NAME', device.name
        script.set_env 'PLATFORM_NAME', 'iOS'
        script.set_env 'PLATFORM_VERSION', device.version

        "#{self.device['serial']} #{@worker_ports.ports['Appium']} #{app_path} #{file_system.results_path}"
      end

      def job_message_klass
        Hive::Messages::IosJob
      end

      def post_script(job, file_system, script)
        @log.info('Post script')
        @worker_ports.ports.each do |name, port|
          @port_allocator.release_port(port)
        end

        device = DeviceAPI::IOS.device(self.device['serial'])
        @installed_apps_after = device.list_installed_packages
        (@installed_apps_after.keys - @installed_apps.keys).each do |app|
          @log.info("Uninstalling #{app} (#{@installed_apps_after[app]['package_name']})")
          device.uninstall(@installed_apps_after[app]['package_name'])
        end
        set_device_status('happy')
      end

      #def device_status
      #
      #end
      #
      #def set_device_status(status)
      #
      #end

      def autogenerated_queues
        [
          "#{@queue_prefix}#{@model}",
          "#{@queue_prefix}ios",
          "#{@queue_prefix}ios-#{@os_version}",
          "#{@queue_prefix}ios-#{@os_version}-#{@model}",
          "#{@queue_prefix}#{@device_range}",
          "#{@queue_prefix}#{@device_range}-#{@os_version}"
        ]
      end

      def hive_mind_device_identifiers
        {
          serial: @serial,
          device_type: 'Mobile'
        }
      end
    end
  end
end
