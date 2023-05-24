module Hypertrace::Config::Environment
  class << self
    include Hypertrace::Logging

    def load_config_from_env
      config = {}

      service_name = Hypertrace::EnvVarSettings.env_value('SERVICE_NAME')
      if service_name
        log.debug "[env] Loaded SERVICE_NAME from env"
        config[:service_name] = service_name
      end

      # Reporting
      config[:reporting] = {}
      reporting_endpoint = Hypertrace::EnvVarSettings.env_value('REPORTING_ENDPOINT')
      if reporting_endpoint
        log.debug "[env] Loaded REPORTING_ENDPOINT from env"
        config[:reporting][:endpoint] = reporting_endpoint
      end

      reporter_type = Hypertrace::EnvVarSettings.env_value('REPORTING_TRACE_REPORTER_TYPE')
      if reporter_type
        log.debug "[env] Loaded REPORTING_TRACE_REPORTER_TYPE from env"
        config[:reporting][:trace_reporter_type] = reporter_type
      end

      reporting_secure = Hypertrace::EnvVarSettings.env_value('REPORTING_SECURE')
      if reporting_secure
        log.debug "[env] Loaded REPORTING_SECURE from env"
        config[:reporting][:secure] = is_true(reporting_secure)
      end

      reporting_token = Hypertrace::EnvVarSettings.env_value('REPORTING_TOKEN')
      if reporting_token
        log.debug("[env] Loaded REPORTING_TOKEN from env")
        config[:reporting][:token] = reporting_token
      end

      config.delete(:reporting) if config[:reporting].empty?

      # Data capture
      config[:data_capture] = {}

      config[:data_capture][:http_headers] = {}
      headers_request = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_HTTP_HEADERS_REQUEST')
      if headers_request
        log.debug("[env] Loaded DATA_CAPTURE_HTTP_HEADERS_REQUEST from env")
        config[:data_capture][:http_headers][:request] = is_true(headers_request)
      end

      headers_response = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_HTTP_HEADERS_RESPONSE')
      if headers_response
        log.debug("[env] Loaded DATA_CAPTURE_HTTP_HEADERS_RESPONSE from env")
        config[:data_capture][:http_headers][:response] = is_true(headers_response)
      end

      config[:data_capture].delete(:http_headers) if config[:data_capture][:http_headers].empty?

      config[:data_capture][:http_body] = {}
      body_request = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_HTTP_BODY_REQUEST')
      if body_request
        log.debug("[env] Loaded DATA_CAPTURE_HTTP_BODY_REQUEST from env")
        config[:data_capture][:http_body][:request] = is_true(body_request)
      end

      body_response = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_HTTP_BODY_RESPONSE')
      if body_response
        log.debug("[env] Loaded DATA_CAPTURE_HTTP_BODY_RESPONSE from env")
        config[:data_capture][:http_body][:response] = is_true(body_response)
      end

      config[:data_capture].delete(:http_body) if config[:data_capture][:http_body].empty?

      config[:data_capture][:rpc_metadata] = {}
      rpc_metadata_request = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_RPC_METADATA_REQUEST')
      if rpc_metadata_request
        log.debug("[env] Loaded DATA_CAPTURE_RPC_METADATA_REQUEST from env")
        config[:data_capture][:rpc_metadata][:request] = is_true(rpc_metadata_request)
      end

      rpc_metadata_response = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_RPC_METADATA_RESPONSE')
      if rpc_metadata_response
        log.debug("[env] Loaded DATA_CAPTURE_RPC_METADATA_RESPONSE from env")
        config[:data_capture][:rpc_metadata][:response] = is_true(rpc_metadata_response)
      end
      config[:data_capture].delete(:rpc_metadata) if config[:data_capture][:rpc_metadata].empty?

      config[:data_capture][:rpc_body] = {}
      rpc_body_request = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_RPC_BODY_REQUEST')
      if rpc_body_request
        log.debug("[env] Loaded DATA_CAPTURE_RPC_BODY_REQUEST from env")
        config[:data_capture][:rpc_body][:request] = is_true(rpc_body_request)
      end

      rpc_body_response = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_RPC_BODY_RESPONSE')
      if rpc_body_response
        log.debug("[env] Loaded DATA_CAPTURE_RPC_BODY_RESPONSE from env")
        config[:data_capture][:rpc_body][:response] = is_true(rpc_body_response)
      end
      config[:data_capture].delete(:rpc_body) if config[:data_capture][:rpc_body].empty?

      body_max_size_bytes = Hypertrace::EnvVarSettings.env_value('DATA_CAPTURE_BODY_MAX_SIZE_BYTES')
      if body_max_size_bytes
        log.debug("[env] Loaded DATA_CAPTURE_BODY_MAX_SIZE_BYTES from env")
        config[:data_capture][:body_max_size_bytes] = body_max_size_bytes.to_i
      end

      config.delete(:data_capture) if config[:data_capture].empty?

      propagation_formats = Hypertrace::EnvVarSettings.env_value(:propagation_formats)
      if propagation_formats && propagation_formats.length > 0
        log.debug("[env] Loaded PROPAGATION_FORMATS from env")
        config[:propagation_formats] = propagation_formats.split(',')
      end

      enabled = Hypertrace::EnvVarSettings.env_value(:enabled)
      if enabled
        log.debug("[env] Loaded ENABLED from env")
        config[:enabled] = is_true(enabled)
      end

      resource_attributes = Hypertrace::EnvVarSettings.env_value(:resource_attributes)
      if resource_attributes
        config[:resource_attributes] = {}
        log.debug('[env] Loaded RESOURCE_ATTRIBUTES from env')
        groups = resource_attributes.split(',')
        groups.each do |group|
          key, value = group.split('=')
          config[:resource_attributes][key] = value
        end
      end

      return config
    end

    def is_true value
      value.downcase == 'true'
    end
  end

end
