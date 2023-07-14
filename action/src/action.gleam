import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/io
import framework.{Response}
import mist
import htmb.{Html, h, text}
import sqlight
import action/database

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn main() {
  let assert Ok(_) = mist.run_service(8000, app, max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub fn app(request: Request(BitString)) {
  use db <- database.with_connection("db.sqlite")

  let context = Context(db: db)
  handle_request(request, context)
  |> response.map(framework.body_to_bit_builder)
}

pub fn handle_request(request: Request(_), context: Context) -> Response {
  let handler = case request.path_segments(request) {
    [] -> home_page
    _ -> fn(_, _) { framework.not_found() }
  }

  handler(request, context)
  |> default_responses
}

pub fn home_page(request: Request(_), _context: Context) -> Response {
  use <- framework.require_method(request, Get)

  home_html()
  |> htmb.render_page(doctype: "html")
  |> framework.html_response(200)
}

fn home_html() -> Html {
  h(
    "div",
    [],
    [
      h("h1", [], [text("Hello, Joe!")]),
      h("p", [], [text("This is a Gleam app!")]),
    ],
  )
}

fn default_responses(response: Response) -> Response {
  case response.status, response.body {
    404, framework.Empty -> {
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_response(404)
    }

    405, framework.Empty -> {
      h("h1", [], [text("There's nothing here")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_response(405)
    }

    400, framework.Empty -> {
      h("h1", [], [text("Invalid request")])
      |> htmb.render_page(doctype: "html")
      |> framework.html_response(400)
    }

    _, _ -> response
  }
}
