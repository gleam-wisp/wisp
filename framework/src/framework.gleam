import gleam/string_builder.{StringBuilder}
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/bool
import gleam/http.{Method}
import gleam/http/request.{Request as HttpRequest}
import gleam/http/response.{Response as HttpResponse}
import gleam/list
import gleam/result
import gleam/string
import gleam/uri

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

// TODO: test
/// This function overrides an incoming POST request with a method given in
/// the request's `_method` query paramerter. This is useful as web browsers
/// typically only support GET and POST requests, but our application may
/// expect other HTTP methods that are more semantically correct.
///
/// The methods PUT, PATCH, and DELETE are accepted for overriding, all others
/// are ignored.
///
/// The `_method` query paramerter can be specified in a HTML form like so:
///
///    <form method="POST" action="/item/1?_method=DELETE">
///      <button type="submit">Delete item</button>
///    </form>
///
pub fn method_override(request: HttpRequest(a)) -> HttpRequest(a) {
  use <- bool.guard(when: request.method != http.Post, return: request)
  {
    use query <- result.try(request.get_query(request))
    use pair <- result.try(list.key_pop(query, "_method"))
    use method <- result.try(http.parse_method(pair.0))

    Ok(case method {
      http.Put | http.Patch | http.Delete -> request.set_method(request, method)
      _ -> request
    })
  }
  |> result.unwrap(request)
}

// TODO: test
// TODO: document
pub fn require_string_body(
  request: Request,
  next: fn(String) -> Response,
) -> Response {
  require(bit_string.to_string(request.body), next)
}

// TODO: replace with a function that also supports multipart forms
// TODO: test
// TODO: document
pub fn require_form_urlencoded_body(
  request: Request,
  next: fn(List(#(String, String))) -> Response,
) -> Response {
  use body <- require_string_body(request)
  require(uri.parse_query(body), next)
}

// TODO: test
// TODO: document
pub fn require(
  result: Result(value, error),
  next: fn(value) -> Response,
) -> Response {
  case result {
    Ok(value) -> next(value)
    Error(_) -> bad_request()
  }
}
