import gleam/string_builder
import gleam/erlang/process
import mist
import wisp

/// The HTTP request handler- your application!
pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use _req <- middleware(req)
  let body = string_builder.from_string("<h1>Hello, Joe!</h1>")
  wisp.html_response(body, 200)
}

/// The middleware stack that the request handler uses.
pub fn middleware(
  req: wisp.Request,
  service: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  service(req)
}

/// Lastly, the main function that runs the service using the Mist HTTP server.
pub fn main() {
  wisp.configure_logger()

  let assert Ok(_) =
    wisp.mist_service(handle_request)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // Mist runs in new Erlang process, so put this one to sleep.
  process.sleep_forever()
}
