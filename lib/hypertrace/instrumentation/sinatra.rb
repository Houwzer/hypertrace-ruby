# frozen_string_literal: true

# Re-open sinatra middleware to customize middleware to call our Hypertrace specific capture
class OpenTelemetry::Instrumentation::Sinatra::Middlewares::TracerMiddleware
  def call env
    extracted_context = OpenTelemetry.propagation.extract(
      env,
      getter: OpenTelemetry::Common::Propagation.rack_env_getter
    )
    OpenTelemetry::Context.with_current(extracted_context) do
      attrs = Hypertrace::Instrumentation::RackCompatible.extract_req_headers_as_attributes(env, 'http.request.header')
      if Hypertrace::Instrumentation::RackCompatible.should_record_env?(env)
        body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(env['rack.input'])
        attrs['http.request.body'] = body_cap if body_cap
      end

      tracer.in_span(
        env['PATH_INFO'],
        attributes: request_span_attributes(env: env).merge!(attrs),
        kind: :server
      ) do |span|
        @app.call(env).tap do |resp|
          response_attributes = Hypertrace::Instrumentation::RackCompatible.extract_response_headers_as_attributes(resp, 'http.response.header')
          if Hypertrace::Instrumentation::RackCompatible.should_record_rack_array?(resp)
            cap_body = Hypertrace::Instrumentation::RackCompatible.extract_response_body(resp)
            response_attributes['http.response.body'] = cap_body if cap_body
          end
          span.add_attributes(response_attributes)
          trace_response(span, env, resp)
        end
      end
    end
  end

  def request_span_attributes(env:)
    attributes = {
      'http.method' => env['REQUEST_METHOD'],
      'http.host' => env['HTTP_HOST'] || 'unknown',
      'http.scheme' => env['rack.url_scheme'],
      'http.target' => env['QUERY_STRING'].empty? ? env['PATH_INFO'] : "#{env['PATH_INFO']}?#{env['QUERY_STRING']}"
    }

    attributes['http.user_agent'] = env['HTTP_USER_AGENT'] if env['HTTP_USER_AGENT']
    attributes
  end
end
