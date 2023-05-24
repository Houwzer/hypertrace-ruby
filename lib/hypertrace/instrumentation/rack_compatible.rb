# frozen_string_literal: true

module Hypertrace
  module Instrumentation
    class RackCompatible

      CONTENT_TYPE_SUBSTRINGS = %w[json x-www-form-urlencoded]

      def self.extract_req_headers_as_attributes env, attr_prefix
        return unless Hypertrace::RubyAgent.instance.config.data_capture.http_headers.request

        headers = extract_headers_from_env(env)
        attr_hash = headers.map do |key, value|
          # https://github.com/rails/rails/blob/a6bf6d55804850b390d840b87a679b784c0a3db4/actionpack/lib/action_dispatch/http/headers.rb#L5-L23
          # in rack underscore and dashes resolve to the same header(using - instead of _)
          key = key.gsub('_', '-')
          ["#{attr_prefix}.#{key}".downcase, value]
        end.to_h

        attr_hash
      end

      def self.should_record_env?(env)
        return false unless env.has_key?("CONTENT_TYPE")
        Hypertrace::Instrumentation::DataCapture.can_capture?(env['CONTENT_TYPE'], Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
      end

      def self.should_record_rack_array?(response)
        content_type_arr = response[1].find{|x|x && x[0].downcase == "content-type"}
        return false unless content_type_arr
        content_type = content_type_arr[1]
        Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
      end

      def self.extract_response_body rack_response
        if rack_response.is_a?(Rack::Response)
          body = rack_response.respond_to?(:body) ? rack_response.body : nil
          return Hypertrace::Instrumentation::DataCapture.capturable_body(body)
        end

        if rack_response.is_a?(Rack::BodyProxy)
          count = 0
          while count < 15
            rack_response = rack_response.instance_variable_get(:'@body')
            if rack_response.is_a?(Array)
              body = rack_response.respond_to?(:join) ? rack_response.join('') : nil
              return Hypertrace::Instrumentation::DataCapture.capturable_body(body)
            end
            if action_dispatch_defined? && rack_response.is_a?(ActionDispatch::Response::RackBody)
              return Hypertrace::Instrumentation::DataCapture.capturable_body(rack_response.body) if rack_response.respond_to?(:body)
            end
            unless rack_response.is_a?(Rack::BodyProxy)
              return
            end
            count += 1
          end
        elsif rack_response.is_a?(Array) && rack_response.length == 3
          body = rack_response[2]
          if body.is_a?(Array)
            return Hypertrace::Instrumentation::DataCapture.capturable_body(body.join(''))
          end
        end
      end

      def self.extract_response_headers_as_attributes rack_response, attr_prefix
        return unless Hypertrace::RubyAgent.instance.config.data_capture.http_headers.response
        return if rack_response.is_a?(Rack::BodyProxy)

        rack_response[1].map do |header, value|
          ["#{attr_prefix}.#{header}".downcase, value]
        end.to_h
      end

      # memoize so we don't check action dispatch
      def self.action_dispatch_defined?
        @_action_dispatch_defined ||= defined?(ActionDispatch) && defined?(ActionDispatch::Response) && defined?(ActionDispatch::Response::RackBody)
      end

      def self.extract_headers_from_env env
        result = env.select{|x|x.start_with?("HTTP_")}
        result.transform_keys!{|k|k[5..-1]}
        if env.has_key?("CONTENT_TYPE")
          result['content-type'] = env['CONTENT_TYPE']
        end
        if env.has_key?("CONTENT_LENGTH")
          result['content-length'] = env["CONTENT_LENGTH"]
        end
        result
      end
    end
  end
end