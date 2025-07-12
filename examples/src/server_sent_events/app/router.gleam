import server_sent_events/app/web
import server_sent_events/app/server_sent_events
import wisp.{type Request}

pub fn handle_request(req: Request) {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> server_sent_events.home_page(req)

    // Connect to the SSE endpoint
    ["sse"] -> server_sent_events.sse(req)

    _ -> wisp.not_found()
  }
}

