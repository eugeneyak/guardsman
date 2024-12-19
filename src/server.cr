require "ecr"
require "ecr/macros"

require "http/server"
require "http/status"
require "http/cookie"

require "uri"

require "log"

require "./profile"
require "./handlers/*"

HOST        = ENV["HOST"]
DOMAIN      = ENV["DOMAIN"]
TG_BOT_NAME = ENV["TG_BOT_NAME"]
TG_TOKEN    = ENV["TG_TOKEN"]

validator = Profile::Validator.new(TG_TOKEN)

index_handler    = Index.new(host: HOST, bot_name: TG_BOT_NAME)
auth_handler     = Auth.new(host: HOST, domain: DOMAIN, validator: validator)
callback_handler = Callback.new(domain: DOMAIN, validator: validator)
teapot_handler   = Teapot.new

server = HTTP::Server.new do |ctx|
  ctx.response.content_type = "text/plain"

  case { ctx.request.method, ctx.request.path }
  when { "GET", "/" }         then index_handler.call(ctx)
  when { "GET", "/auth" }     then auth_handler.call(ctx)
  when { "GET", "/callback" } then callback_handler.call(ctx)
  else                             teapot_handler.call(ctx)
  end
end

address = server.bind_tcp "0.0.0.0", 3000

Log.info { "Listening on http://#{address}" }

server.listen
