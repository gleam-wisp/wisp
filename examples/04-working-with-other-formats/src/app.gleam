import app/router
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    fn(req, _) { router.handle_request(req) }
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
