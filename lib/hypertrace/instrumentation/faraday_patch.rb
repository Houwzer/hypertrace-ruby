class OpenTelemetry::Instrumentation::Faraday::Middlewares::TracerMiddleware < ::Faraday::Middleware
  include Hypertrace::Logging

  def call(env)
    http_method = HTTP_METHODS_SYMBOL_TO_STRING[env.method]
    attributes = span_creation_attributes(
      http_method: http_method, url: env.url
    )
    request_headers = env.request_headers.to_h
    header_attrs = Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(request_headers,
                                                                                      Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)

    content_type = request_headers.find{|k, v| k.downcase == "content-type"}&.last
    if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
      begin
        body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(env.body.to_s) if env.respond_to?(:body) && env.body.respond_to?(:to_s)
        attributes['http.request.body'] = body_cap if body_cap
      rescue => e
        log.error("error attempting to read faraday request body #{e}")
      end
    end

    attributes.merge!(header_attrs)

    tracer.in_span(
      "HTTP #{http_method}", attributes: attributes, kind: :client
    ) do |span|
      OpenTelemetry.propagation.inject(env.request_headers)

      app.call(env).on_complete do |resp|
        resp = Faraday::Response.new(resp)
        resp_headers = resp.headers.to_h
        Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(resp_headers,
                                                                           Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE) do |k, v|
          span.set_attribute(k, v)
        end
        content_type = resp_headers.find{|k, v| k.downcase == "content-type"}&.last
        if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
          begin
            body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(resp.body)
            span.set_attribute('http.response.body', body_cap) if body_cap
          rescue => e
            log.error("error attempting to read faraday response body #{e}")
          end
        end

        trace_response(span, resp)
      end
    end
  end
end