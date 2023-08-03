import sqlight
import framework.{Response}
import htmb.{h, text}
import gleam/bool

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn default_responses(response: Response) -> Response {
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
