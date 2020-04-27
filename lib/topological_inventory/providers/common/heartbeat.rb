module TopologicalInventory
  module Providers
    module Common
      class << self
        attr_writer :heartbeat
      end

      def self.heartbeat(name, max_thread_timeout)
        @heartbeat ||= {}
        @heartbeat[name] ||= TopologicalInventory::Providers::Common::Heartbeat.new(name, max_thread_timeout)
      end

      module HeartbeatQueue
        def heartbeat(name, max_thread_timeout = 65)
          TopologicalInventory::Providers::Common.heartbeat(name, max_thread_timeout)
        end
      end

      class Heartbeat
        HEARTBEAT_CHECK_TIMEOUT             = 12.freeze
        HEARTBEAT_TIMEOUT                   = 10.freeze
        HEARTBEAT_QUEUE_THREAD_TIMEOUT_STEP = 10.freeze
        HEARTBEAT_THREAD_TIMEOUT_STEP       = 10.freeze

        attr_accessor :finished, :heartbeat_queue, :name, :max_thread_timeout, :queue_thread_finished

        def initialize(name, max_thread_timeout = 65)
          self.heartbeat_queue = Concurrent::Array.new([:tick])
          self.finished = Concurrent::AtomicBoolean.new(false)
          self.queue_thread_finished = Concurrent::AtomicBoolean.new(false)
          self.name = name
          self.max_thread_timeout = max_thread_timeout

          self.create_heartbeat_dir
          self.touch_heartbeat_file
        end

        def run_thread
          Thread.new do
            until finished.value
              if self.heartbeat_queue.present?
                self.touch_heartbeat_file
                self.heartbeat_queue.clear
              end

              sleep(HEARTBEAT_TIMEOUT)
            end
          end
        end

        def run_queue_thread_with_timeout
          self.queue_thread_finished = Concurrent::AtomicBoolean.new(false)
          Thread.new do
            current_time_thread = 0

            until queue_thread_finished.value
              sleep(HEARTBEAT_QUEUE_THREAD_TIMEOUT_STEP)

              current_time_thread += HEARTBEAT_QUEUE_THREAD_TIMEOUT_STEP
              if current_time_thread > self.max_thread_timeout
                stop_queue_thread
              else
                self.queue_tick
              end
            end
          end
        end

        def run_thread_queue_in_parallel_with
          run_queue_thread_with_timeout

          yield
        ensure
          stop_queue_thread
        end

        def run_thread_with_timeout
          self.finished = Concurrent::AtomicBoolean.new(false)

          Thread.new do
            current_time_thread = 0
            until finished.value
              sleep(HEARTBEAT_THREAD_TIMEOUT_STEP)

              current_time_thread += HEARTBEAT_THREAD_TIMEOUT_STEP
              if current_time_thread > self.max_thread_timeout
                stop
              else
                self.touch_heartbeat_file
              end
            end
          end
        end

        def run_in_parallel_with
          run_thread_with_timeout

          yield
        ensure
          stop
        end

        def queue_tick
          self.heartbeat_queue << :tick
        end

        def stop
          self.finished = Concurrent::AtomicBoolean.new(true)
        end

        def stop_queue_thread
          self.queue_thread_finished = Concurrent::AtomicBoolean.new(true)
        end

        def touch_heartbeat_file
          File.write(self.heartbeat_file, (Time.now.utc + HEARTBEAT_CHECK_TIMEOUT).to_s)
        end

        def create_heartbeat_dir
          Dir.mkdir(heartbeat_dir) unless File.exist?(heartbeat_dir)
        end

        def heartbeat_dir
          self.class.heartbeat_dir
        end

        def heartbeat_file
          self.class.heartbeat_file(self.name)
        end

        def self.heartbeat_dir
          require 'tmpdir'
          File.join(Dir.tmpdir, 'heartbeat_files')
        end

        def self.heartbeat_file_path(name)
          "#{heartbeat_dir}/heartbeat_file-#{name}.hb"
        end

        def self.heartbeat_file(name)
          File.expand_path(self.heartbeat_file_path(name), __FILE__)
        end

        def self.check(name)
          require 'time'

          hb_file = heartbeat_file(name)

          if File.exist?(hb_file)
            current_time = Time.now.utc
            contents     = File.read(hb_file)
            mtime        = File.mtime(hb_file).utc

            timeout      = if contents.empty?
                             (mtime + HEARTBEAT_CHECK_TIMEOUT).utc
                           else
                             Time.parse(contents).utc
                           end

            current_time <= timeout
          else
            false
          end
        end
      end
    end
  end
end
