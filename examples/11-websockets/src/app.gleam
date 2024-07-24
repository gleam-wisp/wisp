import app/router
import app/web
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    // We create a function which calls our request handler and stores the
    // websocket capability into our custom Context type for use in our
    // websocket routes.
    fn(req, ws) { router.handle_request(req, web.Context(ws)) }
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
