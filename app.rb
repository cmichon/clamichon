module AppHelpers
  def request_access_token(code) #{{{
    @access_response = Faraday.post(
      'https://github.com/login/oauth/access_token',
      {
        client_id: ENV['CLIENT_ID'],
        client_secret: ENV['CLIENT_SECRET'],
        code: code
      },
      { Accept: 'application/json' }
    )    
  end #}}}
  def login_as_user #{{{
    access_token = JSON.parse(@access_response.body)['access_token']
    client = Octokit::Client.new(access_token: access_token)
    @user = client.user
    @locals = {
      login: "#{@user.login}",
      url: "#{@user.html_url}"
    } # will fail if access_token is wrong
  end #}}}
  def cla_signature #{{{
    if User.where(login: @locals[:login]).count == 1
      already_signed
    else
      initial_signature
    end
  end #}}}
  def already_signed #{{{
    @locals[:status] = 'Welcome back!'
  end #}}}
  def initial_signature #{{{
    add_new_cla_user
    remove_pending_state_for_cla_user
    @locals[:status] = 'Success!'
  end #}}}
  def add_new_cla_user #{{{
    User.insert({
      login: @user.login,
      cla_invidual: true,
      full_name: @user.name,
      postal_address: "here",
      country: "any",
      email: @user.email,
      phone: "1234567890"
    })
  end #}}}
  def remove_pending_state_for_cla_user #{{{
    @owner_client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN']) # next ops as repo owner
    Request.where(login: @locals[:login], status: 'pending').each do |e|
      @owner_client.create_status(
        e.repo,
        e.sha,
        'success',
        { context: 'license/cla',
          description: "Contributor License Agreement signed by @#{@locals[:login]}."
        }
      ) rescue nil # we may hit an exception (ex: repo gone), which we clean up next line anyway
      e.update({status: 'open'})
    # e.delete
    end
  end #}}}
  def add_branch_protection #{{{
    @owner_client.protect_branch(
      @repo,
      "master",
      required_status_checks: {
        strict: false,
        contexts: [ 'license/cla' ]
      },
      enforce_admins: false,
      required_pull_request_reviews: nil
    )
  end #}}}
  def get_pr_info #{{{
    @pr_number = @payload["number"]
    @pr = @owner_client.pull_request(@repo, @pr_number)
    @pr_login = @pr.head.user.login
  end #}}}
  def webhook_logic_by_user #{{{
    if User.where(login: @pr_login).count == 1
      webhook_with_signed_cla
    else
      webhook_without_signed_cla
    end
  end #}}}
  def webhook_without_signed_cla #{{{
    @owner_client.create_status(
      @repo,
      @pr.head.sha,
      'pending',
      { context: 'license/cla',
        description: 'Contributor License Agreement is not signed yet.',
        target_url: ENV['CLA_URL']
      }
    )
    @owner_client.add_comment(
      @repo,
      @pr_number,
      'When this pull request was created, the <a href=''' + ENV['CLA_URL'] + '''>Contributor License Agreement</a> was not signed yet.'
    )
    Request.insert({status: 'pending', login: @pr_login, repo: @repo, sha: @pr.head.sha})
  end #}}}
  def webhook_with_signed_cla #{{{
    @owner_client.create_status(
      @repo,
      @pr.head.sha,
      'success',
      { context:'license/cla',
        description: "Contributor License Agreement signed by @#{@pr_login}."
      }
    )
    @owner_client.add_comment(
      @repo,
      @pr_number,
      'When this pull request was created, the Contributor License Agreement was already signed.'
    )
    Request.insert({status: 'open', login: @pr_login, repo: @repo, sha: @pr.head.sha})
  end #}}}
end

class App < Roda
  include AppHelpers
  plugin :public
  plugin :render

  route do |r|
    r.public

    r.root do
      render :index, locals: { client_id: ENV['CLIENT_ID'] }
    end

    r.get 'profile' do
      request_access_token(r.params['code'])
      login_as_user rescue r.redirect('/') # failsafe
      cla_signature
      render :profile, locals: @locals
    end

    r.post 'webhook' do
      @payload = JSON.parse request.body.read
      @repo = @payload["repository"]["full_name"]
      @owner_client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN'])
      case request.env['HTTP_X_GITHUB_EVENT']
      when 'ping'
        add_branch_protection
      when 'pull_request'
        get_pr_info
        webhook_logic_by_user
      else
      end
      "webhook processed"
    end

  end
end

# vim:et:ff=unix:sw=2:ts=2:fdm=marker:fdc=2:
