import app/web.{Context}
import app/web/people
import wisp.{Request, Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["people"] -> people.all(req, ctx)
    ["people", id] -> people.one(req, ctx, id)
    _ -> wisp.not_found()
  }
}
