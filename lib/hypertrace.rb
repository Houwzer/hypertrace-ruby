# frozen_string_literal: true

module Hypertrace
  class Error < StandardError; end
end

require_relative './hypertrace/version'
require_relative './hypertrace/env_var_settings'
require_relative './hypertrace/logging'
require_relative './hypertrace/config'
require_relative './hypertrace/ruby_agent'


