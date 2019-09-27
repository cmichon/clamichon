require 'sinatra'
require 'sinatra/reloader'
require 'yaml'

#~ set :bind, '0.0.0.0'

get '/' do
  "woot"
end

get '/json' do
  #str_body = File.read("file.txt") rescue ""
  #payload = JSON.parse str_body
  #p payload['action']
  #str_body
  ENV.to_h.to_yaml
end

post '/webhook' do
  str_body = request.body.read
  payload = JSON.parse str_body
  File.open('file.txt','w'){|f| f.write str_body}
  event = request.env['HTTP_X_GITHUB_EVENT']
  ""
end

# vim:et:ff=unix:sw=2:ts=2:
