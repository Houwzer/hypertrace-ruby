# frozen_string_literal: true

module Hypertrace::EnvVarSettings
  PREFIXES = ['HT']
  class << self
    def env_value target_key
      PREFIXES.each do |prefix|
        key = "#{prefix}_#{target_key}"
        return ENV[key] if ENV.key?(key)
      end
      nil
    end
  end
end