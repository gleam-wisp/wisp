import app/metrics.{create_standard_metrics}
import app/router
import gleam/erlang/process
import mist
import wisp

pub fn main() {
  // Create the standard HTTP metrics by calling `create_standard_metrics()` here
  create_standard_metrics()

  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp.mist_handler(router.handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
