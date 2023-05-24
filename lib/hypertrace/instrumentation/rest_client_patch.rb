module OpenTelemetry::Instrumentation::RestClient::Patches::Request
  private

  def trace_request
    http_method = method.upcase
    instrumentation_attrs = {
      'http.scheme' => self.use_ssl? ? "https" : "http",
      'http.method' => http_method.to_s,
      'http.url' => OpenTelemetry::Common::Utilities.cleanse_url(url)
    }
    config = OpenTelemetry::Instrumentation::RestClient::Instrumentation.instance.config
    header_map = self.processed_headers
    ht_attributes = Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(header_map,
                                                                                       Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
    content_type = header_map.find{|k,v|k.downcase == 'content-type'}&.last
    if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type,
                                                               Hypertrace::Instrumentation::DataCapture::TYPE_REQUEST)
      body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(self.payload.to_s)
      ht_attributes['http.request.body'] = body_cap if body_cap
    end

    instrumentation_attrs['peer.service'] = config[:peer_service] if config[:peer_service]
    span = tracer.start_span(
      "HTTP #{http_method}",
      attributes: instrumentation_attrs.merge(
        OpenTelemetry::Common::HTTP::ClientContext.attributes,
        ht_attributes
      ),
      kind: :client
    )

    OpenTelemetry::Trace.with_span(span) do
      OpenTelemetry.propagation.inject(processed_headers)
    end

    yield(span).tap do |response|
      # Verify return value is a response.
      # If so, add additional attributes.
      if response.is_a?(::RestClient::Response)
        headers = response.headers
        Hypertrace::Instrumentation::DataCapture.headers_to_attribute_keys(headers, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE) do |attr_key, attr_value|
          span.set_attribute(attr_key, attr_value)
        end
        content_type = headers[:content_type]
        if Hypertrace::Instrumentation::DataCapture.can_capture?(content_type, Hypertrace::Instrumentation::DataCapture::TYPE_RESPONSE)
          body_cap = Hypertrace::Instrumentation::DataCapture.capturable_body(response.body)
          span.set_attribute('http.response.body', body_cap) if body_cap
        end
        span.set_attribute('http.status_code', response.code)
        span.status = OpenTelemetry::Trace::Status.error unless (100..399).include?(response.code.to_i)
      end
    end
  rescue ::RestClient::ExceptionWithResponse => e
    span.set_attribute('http.status_code', e.http_code)
    span.status = OpenTelemetry::Trace::Status.error unless (100..399).include?(e.http_code.to_i)

    raise e
  ensure
    span.finish
  end
end
