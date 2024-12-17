class Index
  getter bot_name
  getter callback_url

  def initialize(bot_name : String, host : String)
    @bot_name     = bot_name
    @callback_url = URI.new(scheme: "https", host: HOST, path: "/callback")
  end

  def call(ctx : HTTP::Server::Context)
    ctx.response.content_type = "text/html"
    ctx.response.print ECR.render("src/index.ecr")
  end
end
