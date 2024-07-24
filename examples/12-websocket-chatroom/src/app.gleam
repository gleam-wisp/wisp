import app/chatroom
import app/router
import app/web
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // We start our main chatroom actor which handles the co-ordination and state
  // of the room. Our clients messages will be sent to this so we need to pass
  // the subject to the websockets to allow communication.
  let assert Ok(subj) = chatroom.start()

  let assert Ok(_) =
    // We add the chatroom subject to our Context type
    fn(req, ws) {
      router.handle_request(req, web.Context(ws: ws, chatroom: subj))
    }
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
