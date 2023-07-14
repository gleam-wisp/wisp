import sqlight
import framework.{Response}
import htmb.{h, text}

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn default_responses(response: Response) -> Response {
  case response.status, response.body {
    404, framework.Empty -> {
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)
    }

    405, framework.Empty -> {
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)
    }

    400, framework.Empty -> {
      h("h1", [], [text("Invalid request")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_body(response, _)
    }

    _, _ -> response
  }
}
