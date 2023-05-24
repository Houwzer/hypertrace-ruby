require 'logger'

module Hypertrace
  module Logging
    def log
      @_logger ||= begin
                     l = Logger.new(STDOUT)
                     l.level = get_level
                     l.progname = 'Hypertrace'
                     l
                   end
    end

    private
    def get_level
      level_map = {
        "debug" => Logger::DEBUG,
        'info' => Logger::INFO,
        'warn' => Logger::WARN,
        'error' => Logger::ERROR
      }

      level = Hypertrace::EnvVarSettings.env_value('LOG_LEVEL') || ''

      level_map.fetch(level.downcase, Logger::INFO)
    end
  end
end