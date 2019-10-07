class App < Roda
  route do |r|

    r.root do
      render :index, locals: { client_id: ENV['CLIENT_ID'] }
    end

    r.get '/profile' do
      access_response = Faraday.post(
        'https://github.com/login/oauth/access_token',
        {
          client_id: ENV['CLIENT_ID'],
          client_secret: ENV['CLIENT_SECRET'],
          code: request.env['rack.request.query_hash']['code']
        },
        { Accept: 'application/json' }
      )
      access_token = JSON.parse(access_response.body)['access_token'] rescue r.redirect '/' # failsafe
      client = Octokit::Client.new(access_token: access_token) rescue r.redirect '/' # failsafe
      locals = {
        login: "#{client.user.login}",
        url: "#{client.user.html_url}"
      }
      if User.where(login: locals[:login]).count == 1
        locals[:status] = 'Welcome back!'
      else
        locals[:status] = 'Success!'
        User.insert({login: locals[:login]})
        client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN']) # next ops as repo owner
        Check.where(login: locals[:login]).each do |e|
          client.create_status(
            e.repo,
            e.sha,
            'success',
            { context: 'license/cla',
              description: "Contributor License Agreement signed by @#{locals[:login]}."
            }
          ) rescue nil # we may hit an exception (ex: repo gone), which we clean up next line anyway
          e.delete
        end
      end
      render :profile, locals: locals
    end

    r.post '/webhook' do
      return "" unless request.env['HTTP_X_GITHUB_EVENT'] == "pull_request" # we only accept pull_request
      payload = JSON.parse request.body.read
      repo = payload["repository"]["full_name"]
      pr_number = payload["number"]
      client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN'])
      pr = client.pull_request(repo, pr_number)
      pr_login = pr.head.user.login
      if User.where(login: pr_login).count == 1
        client.create_status(
          repo,
          pr.head.sha,
          'success',
          { context:'license/cla',
            description: "Contributor License Agreement signed by @#{pr_login}."
          }
        )
        client.add_comment(
          repo,
          pr_number,
          'When this pull request was created, the Contributor License Agreement was already signed.'
        )
      else
        client.create_status(
          repo,
          pr.head.sha,
          'pending',
          { context: 'license/cla',
            description: 'Contributor License Agreement is not signed yet.',
            target_url: 'https://clamichon.herokuapp.com'
          }
        )
        client.add_comment(
          repo,
          pr_number,
          'When this pull request was created, the <a href="https://clamichon.herokuapp.com/">Contributor License Agreement</a> was not signed yet.'
        )
        Check.insert({login: pr_login, repo: repo, sha: pr.head.sha})
      end
      "webhook processed"
    end

  end
end

# vim:et:ff=unix:sw=2:ts=2:
