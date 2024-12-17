class Teapot
  def call(ctx : HTTP::Server::Context)
    ctx.response.status = HTTP::Status::IM_A_TEAPOT
    ctx.response.print "I'm a teapot"
  end
end
