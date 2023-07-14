import gleam/string_builder.{StringBuilder}
import gleam/bit_builder.{BitBuilder}
import gleam/http.{Method}
import gleam/http/response.{Response as HttpResponse}
import gleam/http/request.{Request as HttpRequest}
import gleam/string
import gleam/list

//
// Responses
//

pub type Body {
  Empty
  Text(StringBuilder)
}

/// An alias for a HTTP response containing a `Body`.
pub type Response =
  HttpResponse(Body)

// TODO: test
// TODO: document
pub fn html_response(html: StringBuilder, status: Int) -> Response {
  HttpResponse(status, [#("Content-Type", "text/html")], Text(html))
}

// TODO: test
// TODO: document
pub fn html_body(response: Response, html: StringBuilder) -> Response {
  response
  |> response.set_body(Text(html))
  |> response.set_header("content-type", "text/html")
}

// TODO: test
// TODO: document
pub fn method_not_allowed(permitted: List(Method)) -> Response {
  let allowed =
    permitted
    |> list.map(http.method_to_string)
    |> string.join(", ")
  HttpResponse(405, [#("allow", allowed)], Empty)
}

// TODO: test
// TODO: document
pub fn not_found() -> Response {
  HttpResponse(404, [], Empty)
}

// TODO: test
// TODO: document
pub fn bad_request() -> Response {
  HttpResponse(400, [], Empty)
}

// TODO: test
// TODO: document
pub fn body_to_string_builder(body: Body) -> StringBuilder {
  case body {
    Empty -> string_builder.new()
    Text(text) -> text
  }
}

// TODO: test
// TODO: document
pub fn body_to_bit_builder(body: Body) -> BitBuilder {
  case body {
    Empty -> bit_builder.new()
    Text(text) -> bit_builder.from_string_builder(text)
  }
}

//
// Requests
//

pub type Request =
  HttpRequest(BitString)

// TODO: test
// TODO: document
pub fn require_method(
  request: HttpRequest(t),
  method: Method,
  next: fn() -> Response,
) -> Response {
  case request.method == method {
    True -> next()
    False -> method_not_allowed([method])
  }
}

// TODO: test
// TODO: document
pub const path_segments = request.path_segments
