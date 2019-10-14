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
      access_token = JSON.parse(access_response.body)['access_token']
      user_client = Octokit::Client.new(access_token: access_token)
      user = user_client.user
      locals = {
        login: "#{user.login}",
        url: "#{user.html_url}"
      }
      if User.where(login: user.login).count == 1 # ALREADY_SIGNED
        locals[:status] = 'Welcome back!'
      else # INITIAL_SIGNATURE: ADD NEW CLA USER, RELEASE PENDING SHA1
        User.insert({
          login: user.login,
          cla_invidual: true,
          full_name: user.name,
          postal_address: "here",
          country: "any",
          email: user.email,
          phone: "1234567890"
        })
        owner_client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN']) # ACT AS REPO OWNER
        Request.where(login: user.login, status: 'pending').each do |e|
          owner_client.create_status(
            e.repo,
            e.sha,
            'success',
            { context: 'license/cla',
              description: "Contributor License Agreement signed by @#{user.login}."
            }
          ) rescue nil # WE MAY HIT AN EXCEPTION (EX: REPO GONE), WHICH WE CLEAN UP NEXT LINE ANYWAY
          e.update({status: 'open'}) # WAS: e.delete
        end
        locals[:status] = 'Success!'
      end
      render :profile, locals: locals
    end rescue r.redirect('/') # WILL FAIL IF ACCESS_TOKEN IS WRONG

    r.post 'webhook' do
      payload = JSON.parse request.body.read
      repo = payload["repository"]["full_name"]
      owner_client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN'])
      case request.env['HTTP_X_GITHUB_EVENT']
      when 'ping' # {{{ ADD BRANCH PROTECTION
        owner_client.protect_branch(
          repo,
          "master",
          required_status_checks: {
            strict: false,
            contexts: [ 'license/cla' ]
          },
          enforce_admins: false,
          required_pull_request_reviews: nil
        ) # }}}
      when 'pull_request' # {{{ CLA BUSINESS LOGIC
        pr_number = payload["number"]
        pr = owner_client.pull_request(repo, pr_number)
        pr_login = pr.head.user.login
        if User.where(login: pr_login).count == 1 # ALREADY SIGNED CLA
          owner_client.create_status(
            repo,
            pr.head.sha,
            'success',
            { context:'license/cla',
              description: "Contributor License Agreement signed by @#{pr_login}."
            }
          )
          owner_client.add_comment(
            repo,
            pr_number,
            'When this pull request was created, the Contributor License Agreement was already signed.'
          )
          Request.insert({status: 'open', login: pr_login, repo: repo, sha: pr.head.sha})
        else # NO SIGNED CLA
          owner_client.create_status(
            repo,
            pr.head.sha,
            'pending',
            { context: 'license/cla',
              description: 'Contributor License Agreement is not signed yet.',
              target_url: ENV['CLA_URL']
            }
          )
          owner_client.add_comment(
            repo,
            pr_number,
            'When this pull request was created, the <a href=''' + ENV['CLA_URL'] + '''>Contributor License Agreement</a> was not signed yet.'
          )
          Request.insert({status: 'pending', login: pr_login, repo: repo, sha: pr.head.sha})
        end # }}}
      else
      end
      "webhook processed"
    end

  end
end

# vim:et:ff=unix:sw=2:ts=2:fdm=marker:fdc=2:
