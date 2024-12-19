class Teapot
  Log = ::Log.for(self)

  def call(ctx : HTTP::Server::Context)
    Log.info { "WTF!? Someone attempted to access #{ctx.request.path}" }

    ctx.response.status = HTTP::Status::IM_A_TEAPOT
    ctx.response.print "I'm a teapot"
  end
end
