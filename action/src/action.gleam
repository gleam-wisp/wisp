import gleam/bit_builder.{BitBuilder}
import gleam/string_builder.{StringBuilder}
import gleam/erlang/process
import gleam/http.{Get, Method}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/io
import mist
import nakai/html
import nakai
import framework.{Context}

pub fn main() {
  let assert Ok(_) = mist.run_service(8000, app, max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub fn app(request: Request(BitString)) -> Response(BitBuilder) {
  let context = Context(request: request, state: Nil)
  handle_request(context)
  |> response.map(bit_builder.from_string_builder)
}

pub fn handle_request(context: Context(state)) -> Response(StringBuilder) {
  let handler = case request.path_segments(context.request) {
    [] -> home_page
    _ -> fn(_) { not_found() }
  }

  context
  |> handler
  |> response.map(nakai.to_string_builder)
}

pub fn home_page(context: Context(state)) -> Response(html.Node(t)) {
  use <- require_method(context, Get)

  let html =
    html.div(
      [],
      [html.h1_text([], "Hello, Joe!"), html.p_text([], "This is a Gleam app!")],
    )
  response.new(200)
  |> response.set_body(html)
}

pub fn require_method(
  context: Context(state),
  method: Method,
  next: fn() -> Response(html.Node(t)),
) -> Response(html.Node(t)) {
  case context.request.method == method {
    True -> next()
    False -> method_not_allowed()
  }
}

pub fn not_found() -> Response(html.Node(t)) {
  let html = html.div([], [html.h1_text([], "There's nothing here")])
  response.new(404)
  |> response.set_body(html)
}

pub fn method_not_allowed() -> Response(html.Node(t)) {
  let html = html.div([], [html.h1_text([], "There's nothing here")])
  response.new(405)
  |> response.set_body(html)
}
