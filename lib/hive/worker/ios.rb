require 'hive/worker'
require 'hive/messages/ios_job'

module Hive
  class Worker
    class Ios < Worker

      attr_accessor :device

      def initialize(device)
        self.device = device
        super(device)
      end

      def pre_script(job, file_system, script)

      end

      def job_message_klass
        Hive::Messages::IosJob
      end

      def post_script(job, file_system, script)

      end

      def device_status

      end

      def set_device_status(status)

      end
    end
  end
end