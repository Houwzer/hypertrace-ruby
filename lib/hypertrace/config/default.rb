DEFAULT_AGENT_CONFIG = {
  'enabled': true,
  'propagation_formats': ['TRACECONTEXT'],
  'service_name': 'rubyagent',
  'reporting': {
    'endpoint': 'http://localhost:4318/v1/traces',
    'secure': false,
    'trace_reporter_type': 'OTLP',
    'token': '',
  },
  'data_capture': {
    'http_headers': {
      'request': true,
      'response': true,
    },
    'http_body': {
      'request': true,
      'response': true,
    },
    'rpc_metadata': {
      'request': true,
      'response': true,
    },
    'rpc_body': {
      'request': true,
      'response': true,
    },
    'body_max_size_bytes': 131072
  },
  'resource_attributes': {}
}.freeze