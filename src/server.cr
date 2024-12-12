require "digest/sha256"
require "openssl/hmac"
require "base64"

require "ecr"
require "ecr/macros"

require "http/server"
require "http/status"
require "http/cookie"

require "uri"

HOST        = ENV["HOST"]
DOMAIN      = ENV["DOMAIN"]
TG_BOT_NAME = ENV["TG_BOT_NAME"]
TG_TOKEN    = ENV["TG_TOKEN"]

struct Profile
  getter id         : String
  getter first_name : String
  getter last_name  : String | Nil
  getter username   : String | Nil
  getter photo_url  : String | Nil
  
  getter auth_date  : String
  getter hash       : String

  def initialize(params : URI::Params)
    @id         = params["id"]
    @first_name = params["first_name"]
    @last_name  = params["last_name"]?
    @username   = params["username"]?
    @photo_url  = params["photo_url"]?
    @auth_date  = params["auth_date"]
    @hash       = params["hash"]
  end

  def initialize(encoded : String)
    params = Base64.decode_string(encoded)
    
    initialize URI::Params.parse(params)
  end

  def encode
    params = URI::Params.new

    params["id"] = id
    params["first_name"] = first_name
    params["auth_date"] = first_name
    params["hash"] = hash

    params["last_name"] = last_name.as String if last_name
    params["username"]  = username.as  String if username
    params["photo_url"] = photo_url.as String if photo_url

    Base64.strict_encode(params.to_s)
  end

  def valid?
    key = Digest::SHA256.new.update(TG_TOKEN).final

    dcs = String.build do |io|
      io         << "auth_date="  << auth_date
      io << "\n" << "first_name=" << first_name
      io << "\n" << "id="         << id
      io << "\n" << "last_name="  << last_name.as(String) if last_name
      io << "\n" << "photo_url="  << photo_url.as(String) if photo_url
      io << "\n" << "username="   << username.as(String)  if username
    end

    OpenSSL::HMAC.hexdigest(OpenSSL::Algorithm::SHA256, key, dcs) == hash
  end
end

server = HTTP::Server.new([HTTP::LogHandler.new]) do |context|
  context.response.content_type = "text/plain"

  case { context.request.method, context.request.path }
  when { "GET", "/" }
    bot_name     = TG_BOT_NAME
    callback_url = URI.new(scheme: "https", host: HOST, path: "/callback")

    context.response.content_type = "text/html"
    context.response.print ECR.render("src/index.ecr")

  when { "GET", "/auth" }
    method  = context.request.headers["X-Forwarded-Method"]
    profile_coockie = context.request.cookies["profile"]?

    case { method, profile_coockie }
    when { _, HTTP::Cookie }
      profile = Profile.new(profile_coockie.value)

      context.response.headers["Auth-User-Id"]         = profile.id
      context.response.headers["Auth-User-First-Name"] = profile.first_name
      context.response.headers["Auth-User-Last-Name"]  = profile.last_name || ""
      context.response.headers["Auth-User-Photo-Url"]  = profile.photo_url || ""
      context.response.headers["Auth-User-Username"]   = profile.username  || ""
      
      context.response.status = HTTP::Status::OK

    when { "GET", Nil }
      gate = URI.new(
        scheme: context.request.headers["X-Forwarded-Proto"],
        host:   context.request.headers["X-Forwarded-Host"],
        path:   context.request.headers["X-Forwarded-Uri"]
      )

      to = URI.new(scheme: "https", host: HOST)

      context.response.cookies << HTTP::Cookie.new(
        name: "gate", 
        value: gate.to_s,
        domain: DOMAIN,
        secure: true, 
        http_only: true, 
        samesite: HTTP::Cookie::SameSite::Lax
      )

      context.response.redirect to

    when { _, Nil }
      context.response.status = HTTP::Status::UNAUTHORIZED
    end

  when { "GET", "/callback" }
    profile = Profile.new(context.request.query_params)
    gate    = context.request.cookies["gate"]?

    case { profile, gate }
    when { .valid?, HTTP::Cookie }
      context.response.cookies.delete("gate")
      context.response.cookies << HTTP::Cookie.new(
        name: "profile", 
        value: profile.encode, 
        domain: DOMAIN, 
        secure: true, 
        http_only: true, 
        samesite: HTTP::Cookie::SameSite::Lax
      )

      context.response.redirect(gate.value)
    else
      context.response.status = HTTP::Status::BAD_REQUEST
    end

  else
    context.response.status = HTTP::Status::IM_A_TEAPOT
    context.response.print "I'm a teapot"
  end
end

address = server.bind_tcp "0.0.0.0", 3000

puts "Listening on http://#{address}"

server.listen
