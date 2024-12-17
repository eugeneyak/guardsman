class Auth
  getter host : String
  getter domain : String
  getter validator : Profile::Validator

  def initialize(@host, @domain, @validator)
  end

  def call(ctx : HTTP::Server::Context)
    method  = ctx.request.headers["X-Forwarded-Method"]
    profile = ctx.request.cookies["profile"]? && 
      Profile.new(ctx.request.cookies["profile"].as(HTTP::Cookie).value)

    case { method, profile }
    when { _, Profile }
      if validator.validate(profile)
        render_profile(ctx, profile)
      else
        ctx.response.status = HTTP::Status::UNAUTHORIZED
      end

    when { "GET", Nil }
      redirect_to_login(ctx)

    when { _, Nil }
      ctx.response.status = HTTP::Status::UNAUTHORIZED
    end
  end

  def render_profile(ctx : HTTP::Server::Context, profile : Profile)
    ctx.response.headers["Auth-User-Id"]         = profile.id
    ctx.response.headers["Auth-User-First-Name"] = profile.first_name
    ctx.response.headers["Auth-User-Last-Name"]  = profile.last_name || ""
    ctx.response.headers["Auth-User-Photo-Url"]  = profile.photo_url || ""
    ctx.response.headers["Auth-User-Username"]   = profile.username  || ""
    
    ctx.response.status = HTTP::Status::OK
  end

  def redirect_to_login(ctx : HTTP::Server::Context)
    gate = URI.new(
      scheme: ctx.request.headers["X-Forwarded-Proto"],
      host:   ctx.request.headers["X-Forwarded-Host"],
      path:   ctx.request.headers["X-Forwarded-Uri"]
    )

    ctx.response.cookies << HTTP::Cookie.new(
      name: "gate", 
      value: gate.to_s,
      domain: domain,
      secure: true, 
      http_only: true, 
      samesite: HTTP::Cookie::SameSite::Lax
    )

    to = URI.new(scheme: "https", host: host)

    ctx.response.redirect to
  end
end
