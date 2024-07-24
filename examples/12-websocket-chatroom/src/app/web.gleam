import app/chatroom
import gleam/erlang/process
import wisp
import wisp/wisp_mist

// In addition to the websocket capability, we now need to also store the
// chatrooms subject, which will be used by any new websocket handlers to
// communicate with the chatroom.
pub type Context {
  Context(
    ws: wisp.Ws(wisp_mist.Connection),
    chatroom: process.Subject(chatroom.Event),
  )
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
