require 'eyecare/version'
require 'eyecare/alert'
require 'eyecare/audio'
require 'eyecare/config'
require 'eyecare/daemon'
require 'fileutils'
require 'ffi'

# Hash
class Hash
  def deep_compact
    dup.deep_compact!
  end

  def deep_compact!
    each do |key, value|
      if value.respond_to?(:deep_compact)
        value = value.deep_compact
        value = nil if value.length == 0
      end
      self[key] = value
    end.compact
  end
end

# Eyecare
module Eyecare
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  begin
    attach_function :prctl, [:ulong, :ulong, :ulong, :ulong], :int
  rescue FFI::NotFoundError => e
    puts e
  end

  @config_path = File.expand_path('~/.eyecare/config.yml')

  class << self
    attr_reader :config_path

    def run
      Daemon.start(config[:pid_file]) do
        loop do
          seconds = config[:alert][:interval]
          while seconds > 0
            proc_name(
              'Eyecare - ' + ChronicDuration.output(seconds, format: :short)
            )
            seconds -= 1
            sleep(1)
          end
          alert.show
        end
      end
    end

    def stop
      Daemon.stop(config[:pid_file])
    end

    def alert
      Alert.instance.init(config[:alert])
    end

    def config
      return @config if @config

      config_file = File.expand_path(config_path)

      if File.exist?(config_file) && File.file?(config_file) &&
         File.readable?(config_file)
        @config = Config.load_from_file(config_file)
      end

      @config ||= Config.new
    end

    private

    def proc_name(name)
      $0 = name
      return false unless self.respond_to?(:prctl)

      name = name.slice(0, 16)
      ptr = FFI::MemoryPointer.from_string(name)
      prctl(15, ptr.address, 0, 0)
    ensure
      ptr.free if ptr
    end
  end
end
