require 'octokit'
require 'rest-client'
require 'sinatra'
require 'sinatra/reloader'
require 'yaml'

#~ set :bind, '0.0.0.0'

get '/' do
  #"woot"
  erb :index, :locals => {:client_id => ENV['CLIENT_ID']}
end

get '/profile' do
  # Retrieve temporary authorization grant code
  session_code = request.env['rack.request.query_hash']['code']

  # POST Auth Grant Code + CLIENT_ID/SECRECT in exchange for our access_token
  response = RestClient.post(
    'https://github.com/login/oauth/access_token',
    # POST payload
    { :client_id => ENV['CLIENT_ID'],
      :client_secret => ENV['CLIENT_SECRET'],
      :code => session_code },
    # Request header for JSON response
    :accept => :json)

  erb :profile
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
  #client.create_status 'cmichon/clatest', sha, 'success', { context:'license/cla' }
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
