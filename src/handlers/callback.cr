class Callback
  Log = ::Log.for(self)

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
        Log.info { "Information has been accepted and verified for #{profile.id} #{profile.full_name}" }

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
        Log.info { "Information has been accepted but not verified for #{profile.id} #{profile.full_name}" }
        ctx.response.status = HTTP::Status::UNAUTHORIZED
      end

    else
      Log.info { "Something went wrong" }
      ctx.response.status = HTTP::Status::BAD_REQUEST
    end
  end
end
