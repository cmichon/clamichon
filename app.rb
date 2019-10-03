%w[octokit rest-client sinatra sinatra/reloader].map &method(:require)

#~ set :bind, '0.0.0.0' # needed outside heroku

get '/' do
  erb :index, :locals => {:client_id => ENV['CLIENT_ID']}
end

get '/profile' do
  # Retrieve temporary authorization grant code
  session_code = request.env['rack.request.query_hash']['code']

  # validating OAuth2 authentication
  response = RestClient.post(
    'https://github.com/login/oauth/access_token',
    {
      :client_id => ENV['CLIENT_ID'],
      :client_secret => ENV['CLIENT_SECRET'],
      :code => session_code
    },
    :accept => :json
  )

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
  }) unless User.where(github_login: user.login).count == 1

  # Render profile page, passing in user profile data to be displayed
  erb :profile, :locals => profile_data
end

post '/webhook' do
  str_body = request.body.read
  payload = JSON.parse str_body
  repo = payload["repository"]["full_name"]
  pr_number = payload["number"]
  client = Octokit::Client.new(:access_token => ENV['GITHUB_AUTH_TOKEN'])
  pr = client.pull_request(repo, pr_number)
  pr_login = pr.head.user.login
  if User.where(github_login: pr_login).count == 1
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
