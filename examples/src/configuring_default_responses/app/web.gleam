import gleam/bool
import gleam/string_tree
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  // This new middleware has been added to the stack.
  // It is defined below.
  use <- default_responses

  handle_request(req)
}

pub fn default_responses(handle_request: fn() -> wisp.Response) -> wisp.Response {
  let response = handle_request()

  // The `bool.guard` function is used to return the original request if the
  // body is not `wisp.Empty`.
  use <- bool.guard(when: response.body != wisp.Empty, return: response)

  // You can use any logic to return appropriate responses depending on what is
  // best for your application.
  // I'm going to match on the status code and depending on what it is add
  // different HTML as the body. This is a good option for most applications.
  case response.status {
    404 | 405 ->
      "<h1>There's nothing here</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    400 | 422 ->
      "<h1>Bad request</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    413 ->
      "<h1>Request entity too large</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    500 ->
      "<h1>Internal server error</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    // For other status codes return the original response
    _ -> response
  }
}
