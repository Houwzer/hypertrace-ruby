class Hypertrace::Instrumentation::DataCapture
  include Hypertrace::Logging
  TYPE_REQUEST = 'request'
  TYPE_RESPONSE = 'response'
  CONTENT_TYPE_SUBSTRINGS = %w[json x-www-form-urlencoded]

  def self.headers_to_attribute_keys header_hash, type, &block
    return {} unless header_allowed_by_config?(type)

    attrs = {}
    header_hash.each do |header_key, header_value|
      attr_key = "http.#{type}.header.#{header_key.downcase}"
      header_value = header_value.join(',') if header_value.is_a?(Array)
      if block_given?
        yield attr_key, header_value
      else
        attrs[attr_key] = header_value
      end
    end
    return if block_given?
    return attrs
  end

  def self.capturable_body body_object
    begin
      max_capture = Hypertrace::RubyAgent.config.data_capture.body_max_size_bytes.value
      if body_object.is_a?(String)
        return body_object.byteslice(0..max_capture)
      elsif body_object.is_a?(StringIO)
        result =  body_object.read(max_capture)
        body_object.rewind
        return result
      end
    rescue => e
      log.error("Erroring reading response body" + e.backtrace&.join("\n"))
    end
  end

  def self.can_capture?(content_type, type)
    content_type = content_type.join('') if content_type.is_a?(Array)
    return false unless content_type
    return false unless body_allowed_by_config?(type)

    content_type = content_type.downcase
    CONTENT_TYPE_SUBSTRINGS.each do |substring|
      if content_type.include?(substring)
        return true
      end
    end
    false
  end

  def self.header_allowed_by_config? type
    return Hypertrace::RubyAgent.config.data_capture.http_headers.request.value if type == TYPE_REQUEST
    Hypertrace::RubyAgent.config.data_capture.http_headers.response.value
  end

  def self.body_allowed_by_config? type
    return Hypertrace::RubyAgent.config.data_capture.http_body.request.value if type == TYPE_REQUEST
    Hypertrace::RubyAgent.config.data_capture.http_body.response.value
  end
end