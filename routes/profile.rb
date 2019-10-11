class App
  hash_path 'profile' do |r|
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
    if User.where(login: locals[:login]).count == 1
      locals[:status] = 'Welcome back!'
    else
      locals[:status] = 'Success!'
      User.insert({
        login: client.user.login,
        cla_invidual: true,
        full_name: client.user.name,
        postal_address: "here",
        country: "any",
        email: client.user.email,
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
end

# vim:et:ff=unix:sw=2:ts=2:
