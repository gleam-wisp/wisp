import action/applications
import action/html.{h, text}
import action/web.{Context}
import framework.{Request, Response}
// TODO: import from framework once we have constructor re-exports
import gleam/http.{Get}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case framework.path_segments(req) {
    ["take-action"] -> applications.resource(req, ctx)
    [] -> home_page(req)
    _ -> framework.not_found()
  }
}

pub fn home_page(request: Request) -> Response {
  use <- framework.require_method(request, Get)
  home_html()
  |> framework.html_response(200)
}

fn home_html() {
  h(
    "div",
    [],
    [
      h("h1", [], [text("Hello, Joe!")]),
      h("p", [], [text("This is a Gleam app!")]),
    ],
  )
  |> html.page
}
