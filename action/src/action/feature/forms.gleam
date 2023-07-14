import action/web.{Context}
import framework.{Request, Response}
import gleam/http.{Get, Patch}

pub fn resource(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> new_application(req, ctx)
    Patch -> update_application(req, ctx)
    _ -> framework.method_not_allowed([Get, Patch])
  }
}

// TODO: implement
// TODO: test
fn new_application(_req: Request, _ctx: Context) -> Response {
  framework.not_found()
}

// TODO: implement
// TODO: test
fn update_application(_req: Request, _ctx: Context) -> Response {
  framework.not_found()
}
