# frozen_string_literal: true

class OpenTelemetry::Instrumentation::Rack::Middlewares::TracerMiddleware
  include Hypertrace::Logging

  def call(env)
    if untraced_request?(env)
      OpenTelemetry::Common::Utilities.untraced do
        return @app.call(env)
      end
    end

    original_env = env.dup
    extracted_context = OpenTelemetry.propagation.extract(
      env,
      getter: OpenTelemetry::Common::Propagation.rack_env_getter
    )
    frontend_context = create_frontend_span(env, extracted_context)

    # restore extracted context in this process:
    OpenTelemetry::Context.with_current(frontend_context || extracted_context) do
      request_span_name = create_request_span_name(env['REQUEST_URI'] || original_env['PATH_INFO'], env)
      request_span_kind = frontend_context.nil? ? :server : :internal

      ht_attributes = Hypertrace::Instrumentation::RackCompatible.extract_req_headers_as_attributes(env, 'http.request.header')
      content_type = env['CONTENT_TYPE']
      if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type,
                                                               Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)

        body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(env['rack.input'])
        ht_attributes['http.request.body'] = body_cap if body_cap
      end

      tracer.in_span(request_span_name,
                     attributes: request_span_attributes(env: env).merge(ht_attributes),
                     kind: request_span_kind) do |request_span|
        OpenTelemetry::Instrumentation::Rack.with_span(request_span) do
          @app.call(env).tap do |status, headers, response|

            response_headers = headers.to_hash
            Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(response_headers, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
            response_headers.each do |h_k, h_v|
              request_span.set_attribute("http.response.header.#{h_k.downcase}", h_v)
            end
            content_type_arr = response_headers.find{|x|x[0].downcase == "content-type"}
            begin
              if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type_arr&.join(''),
                                                                       Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
                cap_body = Hypertrace::Instrumentation::RackCompatible.extract_response_body(response)
                request_span.set_attribute('http.response.body', cap_body) if cap_body
              end

              set_attributes_after_request(request_span, status, headers, response)
            rescue => e
              log.error("Error in Hypertrace response capture" + e.backtrace&.join("\n"))
            end
          end
        end
      end
    end
  ensure
    finish_span(frontend_context)
  end
end