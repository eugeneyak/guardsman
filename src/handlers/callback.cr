class Callback
  getter domain : String
  getter validator : Profile::Validator

  def initialize(@domain, @validator)
  end

  def call(ctx : HTTP::Server::Context)
    profile = Profile.new(ctx.request.query_params)
    gate    = ctx.request.cookies["gate"]?

    case { profile, gate }
    when { Profile, HTTP::Cookie }
      if validator.validate(profile)
        ctx.response.cookies.delete("gate")
        ctx.response.cookies << HTTP::Cookie.new(
          name: "profile", 
          value: profile.encode, 
          domain: domain, 
          secure: true, 
          http_only: true, 
          samesite: HTTP::Cookie::SameSite::Lax
        )
  
        ctx.response.redirect(gate.value)
      else
        ctx.response.status = HTTP::Status::UNAUTHORIZED
      end

    else
      ctx.response.status = HTTP::Status::BAD_REQUEST
    end
  end
end
