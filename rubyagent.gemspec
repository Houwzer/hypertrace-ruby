# frozen_string_literal: true

require_relative "lib/hypertrace/version"

Gem::Specification.new do |spec|
  spec.name = "hypertrace-agent"
  spec.version = Hypertrace::VERSION
  spec.authors = ["prodion23"]
  spec.email = ["Write your email address"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.description = "Hypertrace ..."
  spec.homepage = "https://hypertrace.com"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/hypertrace/rubyagent"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency 'google-protobuf', '3.21.5'
  spec.add_dependency 'opentelemetry-api', '1.0.2'
  spec.add_dependency 'opentelemetry-sdk', '1.1.0'
  spec.add_dependency 'opentelemetry-propagator-b3', '0.20.0'
  spec.add_dependency 'opentelemetry-exporter-otlp', '0.21.1'
  spec.add_dependency 'opentelemetry-exporter-zipkin', '0.20.0'
  spec.add_dependency 'opentelemetry-instrumentation-faraday', '0.21.0'
  spec.add_dependency 'opentelemetry-instrumentation-mysql2', '0.21.0'
  spec.add_dependency 'opentelemetry-instrumentation-pg', '0.21.0'
  spec.add_dependency 'opentelemetry-instrumentation-mongo', '0.20.0'
  spec.add_dependency 'opentelemetry-instrumentation-net_http', '0.20.0'
  spec.add_dependency 'opentelemetry-instrumentation-http', '0.20.0'
  spec.add_dependency 'opentelemetry-instrumentation-rails', '0.22.0'
  spec.add_dependency 'opentelemetry-instrumentation-restclient', '0.20.0'
  spec.add_dependency 'opentelemetry-instrumentation-sinatra', '0.20.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
