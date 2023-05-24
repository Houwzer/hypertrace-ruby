require 'yaml'
class Hypertrace::Config::Config
  include Hypertrace::Logging
  attr_reader :config
  def initialize
    @config = load_config
  end

  def load_config
    # Order of loading:
    # 1.) Defaults
    # 2.) Overriden by config file
    # 3.) Overriden by env vars
    config = Marshal.load(Marshal.dump(DEFAULT_AGENT_CONFIG))

    file_config = load_file
    config = merge_config(config, file_config)

    env_config = Hypertrace::Config::Environment.load_config_from_env
    config = merge_config(config, env_config)

    log.info "Finalized config loaded"
    log.info config

    proto_config = Hypertrace::Agent::Config::V1::AgentConfig.new
    enabled = Google::Protobuf::BoolValue.new({value: config[:enabled]})
    proto_config.enabled = enabled
    proto_config.propagation_formats += config[:propagation_formats]
    service_name = Google::Protobuf::StringValue.new({value: config[:service_name]})
    proto_config.service_name = service_name

    proto_config.reporting = Hypertrace::Agent::Config::V1::Reporting.new
    endpoint = Google::Protobuf::StringValue.new({value: config[:reporting][:endpoint]})
    proto_config.reporting.endpoint = endpoint
    secure = Google::Protobuf::BoolValue.new({value: config[:reporting][:secure]})
    proto_config.reporting.secure = secure

    proto_config.reporting.trace_reporter_type = config[:reporting][:trace_reporter_type]

    proto_config.data_capture = Hypertrace::Agent::Config::V1::DataCapture.new
    %i[http_headers http_body rpc_metadata rpc_body].each do |field|
      message_instance = Hypertrace::Agent::Config::V1::Message.new
      message_instance.request = Google::Protobuf::BoolValue.new({value:config[:data_capture][field][:request]})
      message_instance.response = Google::Protobuf::BoolValue.new({value:config[:data_capture][field][:response]})
      proto_config.data_capture[field.to_s] = message_instance
    end
    proto_config.data_capture.body_max_size_bytes = Google::Protobuf::Int32Value.new({value: config[:data_capture][:body_max_size_bytes]})

    proto_config.resource_attributes.merge(config[:resource_attributes])
    proto_config
  end

  def load_file
    file_path = Hypertrace::EnvVarSettings.env_value('CONFIG_FILE')
    return {} if file_path.nil?

    begin
      yaml_content = File.read(file_path)
      config_file_contents = YAML.load(yaml_content, symbolize_names: true)
    rescue => e
      log.warn "failed to load config file: #{file_path}"
    end
    config_file_contents || {}
  end

  def merge_config(base_config, overriding_config)
    overriding_config.each_key do |key|
      if base_config.key?(key) && base_config[key].instance_of?(Hash)
        base_config[key] = merge_config(base_config[key], overriding_config[key])
      else
        base_config[key] = overriding_config[key]
      end
    end

    base_config
  end
end