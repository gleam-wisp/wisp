import wisp
import wisp/wisp_mist

// We need to store the Websocket capability provided by our server which we
// will use to create a websocket route. This provides the connection
// information of the socket connection to be upgraded into a websocket.
pub type Context {
  Context(ws: wisp.Ws(wisp_mist.Connection))
}

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}
