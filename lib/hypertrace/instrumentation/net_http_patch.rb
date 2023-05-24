module OpenTelemetry::Instrumentation::Net::HTTP::Patches::Instrumentation
  def request(req, body = nil, &block)
    # Do not trace recursive call for starting the connection
    return super(req, body, &block) unless started?

    scheme = use_ssl? ? "https://" : "http"
    url = "#{scheme}#{@address}:#{@port}#{req.path}"
    attributes = {
      OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD => req.method,
      OpenTelemetry::SemanticConventions::Trace::HTTP_SCHEME => USE_SSL_TO_SCHEME[use_ssl?],
      OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET => req.path,
      OpenTelemetry::SemanticConventions::Trace::NET_PEER_NAME => @address,
      OpenTelemetry::SemanticConventions::Trace::NET_PEER_PORT => @port,
      OpenTelemetry::SemanticConventions::Trace::HTTP_URL =>  url
    }.merge!(OpenTelemetry::Common::HTTP::ClientContext.attributes)

    header_map = req.instance_variable_get(:@header)
    ht_attributes = Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(header_map,
                                                                                      Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
    content_type = header_map.find{|k, v| k.downcase == "content-type"}&.last
    if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
      body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(req.body)
      ht_attributes['http.request.body'] = body_cap if body_cap
    end
    tracer.in_span(
      HTTP_METHODS_TO_SPAN_NAMES[req.method],
      attributes: attributes.merge!(ht_attributes),
      kind: :client
    ) do |span|
      OpenTelemetry.propagation.inject(req)

      super(req, body, &block).tap do |response|
        response_headers = response.instance_variable_get(:@header)
        Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(response_headers,
                                                                           Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE) do |k, v|
          span.set_attribute(k, v)
        end
        content_type = response_headers.find{|k, v| k.downcase == "content-type"}&.last
        if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
          span.set_attribute('http.response.body', Hypertrace::Instrumentation::DataCapture.capturable_body(response.body))
        end
        annotate_span_with_response!(span, response)
      end
    end
  end
end