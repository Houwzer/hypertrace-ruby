require 'sinatra'
require_relative '../../lib/hypertrace'
Hypertrace::RubyAgent.instance.instrument!

get '/' do
  "Hello World"
end
