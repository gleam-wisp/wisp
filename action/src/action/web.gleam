import sqlight
import framework.{Request, Response}
import htmb.{h, text}
import gleam/bool

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn middleware(req: Request, service: fn(Request) -> Response) -> Response {
  let req = framework.method_override(req)
  use <- serve_default_responses
  use <- framework.rescue_crashes

  service(req)
}

fn serve_default_responses(service: fn() -> Response) -> Response {
  let response = service()
  use <- bool.guard(response.body != framework.Empty, return: response)

  case response.status {
    404 ->
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)

    405 ->
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)

    400 ->
      h("h1", [], [text("Invalid request")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)

    413 ->
      h("h1", [], [text("Request entity too large")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)

    _ -> response
  }
}
