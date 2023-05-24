# frozen_string_literal: true

require 'opentelemetry-sdk'
require 'opentelemetry/exporter/zipkin'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/propagator/b3'
require 'opentelemetry/trace/propagation/trace_context'
require 'opentelemetry/instrumentation/faraday'
require 'opentelemetry/instrumentation/net/http'
require 'opentelemetry/instrumentation/http'
require 'opentelemetry/instrumentation/mongo'
require 'opentelemetry/instrumentation/mysql2'
require 'opentelemetry/instrumentation/pg'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry/instrumentation/rails'
require 'opentelemetry/instrumentation/restclient'
require 'opentelemetry/instrumentation/sinatra'
require_relative './instrumentation'
require_relative './instrumentation/data_capture'

require_relative './instrumentation/rack_compatible'
require_relative './config'
require_relative './instrumentation/sinatra'
require_relative './version'

require 'singleton'

# We can't name the class 'Hypertrace::Agent' because the built proto definitions
# create a module Hypertrace::Agent :(
# RubyAgent is repetitve, but want to remain somewhat consistent compared to python/node
class Hypertrace::RubyAgent
  include Hypertrace::Logging
  include Singleton

  def self.instrument!
    self.instance.instrument!
  end

  def self.config
    self.instance.config
  end

  def initialize(version = Hypertrace::VERSION)
    log.info {"Initializing Hypertrace"}
    configure_otel_logger!
    @config = Hypertrace::Config::Config.new
    @version = version
    log.info {"Hypertrace version: #{Hypertrace::VERSION}"}
    log.info {"Ruby version: #{RUBY_VERSION}"}
  end

  def config
    @config.config
  end

  def instrument!
    initalize_tracer
  end

  def initalize_tracer
    resource = OpenTelemetry::SDK::Resources::Resource.create(create_resource_attributes)

    # TODO: Extra resource Attributes From Config
    exporter = create_exporter
    OpenTelemetry::SDK.configure do |c|
      if ENV['HT_CI_TEST'] != nil
        span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)
        c.add_span_processor span_processor
      else
        c.add_span_processor OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
      end
      c.resource = resource

      c.use 'OpenTelemetry::Instrumentation::ActionPack'
      c.use 'OpenTelemetry::Instrumentation::ActionView'
      c.use 'OpenTelemetry::Instrumentation::ActiveRecord'
      c.use 'OpenTelemetry::Instrumentation::ActiveSupport'
      c.use 'OpenTelemetry::Instrumentation::Faraday'
      c.use 'OpenTelemetry::Instrumentation::Mongo'
      c.use 'OpenTelemetry::Instrumentation::Mysql2'
      c.use 'OpenTelemetry::Instrumentation::PG'
      c.use 'OpenTelemetry::Instrumentation::Rack'
      c.use 'OpenTelemetry::Instrumentation::Sinatra'
      c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
      c.use 'OpenTelemetry::Instrumentation::HTTP'
      c.use 'OpenTelemetry::Instrumentation::RestClient'
    end

    apply_custom_patch './instrumentation/rack'
    apply_custom_patch './instrumentation/net_http_patch'
    apply_custom_patch './instrumentation/http_patch'
    apply_custom_patch './instrumentation/faraday_patch'
    apply_custom_patch './instrumentation/rest_client_patch'

    configure_propagators
  end

  private

  def create_exporter
    exporter = nil
    if config.reporting.trace_reporter_type == :OTLP
      verify_mode = config.reporting.secure.value ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: config.reporting.endpoint.value,
                                                             ssl_verify_mode: verify_mode)
      return exporter
    end
    if config.reporting.trace_reporter_type == :ZIPKIN
      exporter = OpenTelemetry::Exporter::Zipkin::Exporter.new(endpoint: config.reporting.endpoint.value)
      return exporter
    end
  end

  def configure_propagators
    propagator_list = []

    [config.propagation_formats.to_a].each do |format|
      if format[0] == :TRACECONTEXT
        propagator_list << OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator
      elsif format[0] == :B3
        propagator_list << OpenTelemetry::Propagator::B3::Single.text_map_propagator
      end
    end
    if propagator_list.empty?
      log.warn{"No propagators were added!"}
    end
    OpenTelemetry.propagation = OpenTelemetry::Context::Propagation::CompositeTextMapPropagator.compose_propagators(propagator_list.compact)
  end

  private

  def apply_custom_patch file
    begin
      require_relative file
      log.debug{"Applied patch for #{file}"}
    rescue => _e
      log.debug{"Unable to apply patch for #{file} this is most likely because the library is unavailable or an unsupported version"}
    end
  end

  def create_resource_attributes
    {
      'service.name': config.service_name.value,
      'service.instance.id': Process.pid,
      'telemetry.sdk.version': @version,
      'telemetry.sdk.name': 'hypertrace',
      'telemetry.sdk.language': 'ruby'
    }.transform_keys(&:to_s)
  end

  NULL_LOGGER = Logger.new(File::NULL)

  def configure_otel_logger!
    OpenTelemetry.logger = NULL_LOGGER
  end
end