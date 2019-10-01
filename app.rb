require 'octokit'
require 'sinatra'
require 'sinatra/reloader'
require 'yaml'

#~ set :bind, '0.0.0.0'

get '/' do
  "woot"
end

#get '/db' do
#  DB.to_s
#end

#get '/json' do
  #str_body = File.read("file.txt") rescue ""
  #payload = JSON.parse str_body
  #p payload['action']
  #str_body
  #ENV.to_h.to_yaml
#end

post '/webhook' do
  str_body = request.body.read
  payload = JSON.parse str_body
  repo = payload["repository"]["full_name"]
  pr_number = payload["number"]
  #File.open('file.txt','w'){|f| f.write str_body}
  #event = request.env['HTTP_X_GITHUB_EVENT']
  client = Octokit::Client.new(:access_token => ENV['GITHUB_AUTH_TOKEN'])
  pr = client.pull_request(repo, pr_number)
  client.create_status 'cmichon/clatest', sha, 'success', { context:'license/cla' }
  client.create_status(
    repo,
    pr.head.sha,
    'pending',
    { :context => 'license/cla',
      :description => 'Contributor License Agreement is not signed yet.',
      :state => 'pending',
      :target_url => 'http://clamichon.herokuapp.com'
    }
  )
  "cla processed"
end

# vim:et:ff=unix:sw=2:ts=2:
