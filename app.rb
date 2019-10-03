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
  p request.env
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

  # Parse access_token from JSON response
  access_token = JSON.parse(response)['access_token']

  # Initialize Octokit client with user access_token
  client = Octokit::Client.new(:access_token => access_token)

  # Create user object for less typing
  user = client.user

  # Access user data
  profile_data = {
    user_login: user.login,
    user_url: user.html_url
  }

  User.insert({
    email: "x",
    full_name: "x",
    github_login: user.login
  })

  # Render profile page, passing in user profile data to be displayed
  erb :profile, :locals => profile_data
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
  pr_login = pr.head.user.login
  if User.where(github_login: pr_login).count
    client.create_status(
      repo,
      pr.head.sha,
      'success',
      { context:'license/cla',
        :description => "Contributor License Agreement signed by @#{pr_login}.",
        :state => 'success'
      }
    )
  else
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
  end
  "cla processed"
end

# vim:et:ff=unix:sw=2:ts=2:
