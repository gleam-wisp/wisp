import app/metrics.{record_http_metrics}
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  // Use the `record_http_metrics` middleware here
  use <- record_http_metrics(req)

  use req <- wisp.handle_head(req)

  handle_request(req)
}
