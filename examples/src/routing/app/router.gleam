import gleam/http.{Get, Post}
import gleam/string_tree
import routing/app/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response(a, b, c) {
  use req <- web.middleware(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> home_page(req)

    // This matches `/comments`.
    ["comments"] -> comments(req)

    // This matches `/comments/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    ["comments", id] -> show_comment(req, id)

    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn home_page(req: Request) -> Response(a, b, c) {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  let html = string_tree.from_string("Hello, Joe!")
  wisp.ok()
  |> wisp.html_body(html)
}

fn comments(req: Request) -> Response(a, b, c) {
  // This handler for `/comments` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method {
    Get -> list_comments()
    Post -> create_comment(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_comments() -> Response(a, b, c) {
  // In a later example we'll show how to read from a database.
  let html = string_tree.from_string("Comments!")
  wisp.ok()
  |> wisp.html_body(html)
}

fn create_comment(_req: Request) -> Response(a, b, c) {
  // In a later example we'll show how to parse data from the request body.
  let html = string_tree.from_string("Created")
  wisp.created()
  |> wisp.html_body(html)
}

fn show_comment(req: Request, id: String) -> Response(a, b, c) {
  use <- wisp.require_method(req, Get)

  // The `id` path parameter has been passed to this function, so we could use
  // it to look up a comment in a database.
  // For now we'll just include in the response body.
  let html = string_tree.from_string("Comment with id " <> id)
  wisp.ok()
  |> wisp.html_body(html)
}
