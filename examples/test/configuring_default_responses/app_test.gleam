import configuring_default_responses/app/router
import gleam/http
import gleam/string
import wisp/simulate

pub fn home_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>Hello, Joe!</h1>")
}

pub fn internal_server_error_test() {
  let response =
    router.handle_request(simulate.browser_request(
      http.Get,
      "/internal-server-error",
    ))

  assert response.status == 500

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>Internal server error</h1>")
}

pub fn unprocessable_entity_test() {
  let response =
    router.handle_request(simulate.browser_request(
      http.Get,
      "/unprocessable-entity",
    ))

  assert response.status == 422

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn bad_request_test() {
  let response =
    router.handle_request(simulate.browser_request(http.Get, "/bad-request"))

  assert response.status == 400

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn method_not_allowed_test() {
  let response =
    router.handle_request(simulate.browser_request(
      http.Get,
      "/method-not-allowed",
    ))

  assert response.status == 405

  assert response.headers
    == [
      #("allow", ""),
      #("content-type", "text/html; charset=utf-8"),
    ]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn not_found_test() {
  let response =
    router.handle_request(simulate.browser_request(http.Get, "/not-found"))

  assert response.status == 404

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn entity_too_large_test() {
  let response =
    router.handle_request(simulate.browser_request(
      http.Get,
      "/entity-too-large",
    ))

  assert response.status == 413

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> simulate.read_body
    |> string.contains("<h1>Request entity too large</h1>")
}
