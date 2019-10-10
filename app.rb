class App < Roda
  plugin :public
  plugin :render

  route do |r|

    r.public

    r.root do
      render :index, locals: { client_id: ENV['CLIENT_ID'] }
    end

    r.get 'profile' do
      access_response = Faraday.post(
        'https://github.com/login/oauth/access_token',
        {
          client_id: ENV['CLIENT_ID'],
          client_secret: ENV['CLIENT_SECRET'],
          code: r.params['code']
        },
        { Accept: 'application/json' }
      )
      begin
        access_token = JSON.parse(access_response.body)['access_token']
        client = Octokit::Client.new(access_token: access_token) 
        locals = {
          login: "#{client.user.login}",
          url: "#{client.user.html_url}"
        }
      rescue # failsafe
        r.redirect('/')
      end
      p client.user
      if User.where(login: locals[:login]).count == 1
        locals[:status] = 'Welcome back!'
      else
        locals[:status] = 'Success!'
        User.insert({
          login: locals[:login],
          cla_invidual: true,
          full_name: "bibi",
          postal_address: "here",
          country: "any",
          email: "email@github.com",
          phone: "1234567890"
        })
        client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN']) # next ops as repo owner
        Request.where(login: locals[:login], status: 'pending').each do |e|
          client.create_status(
            e.repo,
            e.sha,
            'success',
            { context: 'license/cla',
              description: "Contributor License Agreement signed by @#{locals[:login]}."
            }
          ) rescue nil # we may hit an exception (ex: repo gone), which we clean up next line anyway
          e.update({status: 'open'})
        # e.delete
        end
      end
      render :profile, locals: locals
    end

    r.post 'webhook' do
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
            target_url: ENV['CLA_URL']
          }
        )
        client.add_comment(
          repo,
          pr_number,
          'When this pull request was created, the <a href=''' + ENV['CLA_URL'] + '''>Contributor License Agreement</a> was not signed yet.'
        )
        Request.insert({status: 'pending', login: pr_login, repo: repo, sha: pr.head.sha})
      end
      "webhook processed"
    end

  end
end

# vim:et:ff=unix:sw=2:ts=2:
