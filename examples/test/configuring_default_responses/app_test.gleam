import configuring_default_responses/app/router
import gleam/string
import wisp/testing

pub fn home_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Hello, Joe!</h1>")
}

pub fn internal_server_error_test() {
  let response =
    router.handle_request(testing.get("/internal-server-error", []))

  assert response.status == 500

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Internal server error</h1>")
}

pub fn unprocessable_entity_test() {
  let response = router.handle_request(testing.get("/unprocessable-entity", []))

  assert response.status == 422

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn bad_request_test() {
  let response = router.handle_request(testing.get("/bad-request", []))

  assert response.status == 400

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn method_not_allowed_test() {
  let response = router.handle_request(testing.get("/method-not-allowed", []))

  assert response.status == 405

  assert response.headers
    == [
      #("allow", ""),
      #("content-type", "text/html; charset=utf-8"),
    ]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn not_found_test() {
  let response = router.handle_request(testing.get("/not-found", []))

  assert response.status == 404

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn entity_too_large_test() {
  let response = router.handle_request(testing.get("/entity-too-large", []))

  assert response.status == 413

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Request entity too large</h1>")
}
