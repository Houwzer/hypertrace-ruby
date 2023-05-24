module OpenTelemetry::Instrumentation::HTTP::Patches::Client
  def perform(req, options)
    uri = req.uri
    request_method = req.verb.to_s.upcase

    headers = req.headers.to_h
    attrs = Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(headers,
                                                                                      Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
    content_type = headers.find{|k, v| k.downcase == "content-type"}&.last
    if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
      body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(req.body.source)
      attrs['http.request.body'] = body_cap if body_cap
    end

    attributes = {
      'http.method' => request_method,
      'http.scheme' => uri.scheme,
      'http.target' => uri.path,
      'http.url' => uri.to_s,
      'net.peer.name' => uri.host,
      'net.peer.port' => uri.port
    }.merge!(OpenTelemetry::Common::HTTP::ClientContext.attributes).merge!(attrs)

    tracer.in_span("HTTP #{request_method}", attributes: attributes, kind: :client) do |span|
      OpenTelemetry.propagation.inject(req.headers)
      super.tap do |response|
        response_headers = response.headers.to_h
        Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(response_headers,
                                                                           Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE) do |k, v|
          span.set_attribute(k, v)
        end
        content_type = response_headers.find{|k, v| k.downcase == "content-type"}&.last
        if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
          body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(response.body.to_s)
          span.set_attribute('http.response.body', body_cap) if body_cap
        end
        annotate_span_with_response!(span, response)
      end
    end
  end
end