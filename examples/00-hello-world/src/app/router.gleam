import app/web
import gleam/string_tree
import wisp.{type Request, type Response}

/// The HTTP request handler- your application!
/// 
pub fn handle_request(req: Request) -> Response {
  // Apply the middleware stack for this request/response.
  use _req <- web.middleware(req)

  // Later we'll use templates, but for now a string will do.
  let body = string_tree.from_string("<h1>Hello, Joe!</h1>")

  // Return a 200 OK response with the body and a HTML content type.
  wisp.html_response(body, 200)
}
