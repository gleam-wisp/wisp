import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist
import working_with_websockets/app/router

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    router.handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8001)
    |> mist.start

  process.sleep_forever()
}
