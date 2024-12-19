import app/router
import gleam/string
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn home_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Hello, Joe!</h1>")
}

pub fn internal_server_error_test() {
  let response =
    router.handle_request(testing.get("/internal-server-error", []))

  response.status
  |> should.equal(500)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Internal server error</h1>")
}

pub fn unprocessable_entity_test() {
  let response = router.handle_request(testing.get("/unprocessable-entity", []))

  response.status
  |> should.equal(422)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn bad_request_test() {
  let response = router.handle_request(testing.get("/bad-request", []))

  response.status
  |> should.equal(400)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Bad request</h1>")
}

pub fn method_not_allowed_test() {
  let response = router.handle_request(testing.get("/method-not-allowed", []))

  response.status
  |> should.equal(405)

  response.headers
  |> should.equal([
    #("allow", ""),
    #("content-type", "text/html; charset=utf-8"),
  ])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn not_found_test() {
  let response = router.handle_request(testing.get("/not-found", []))

  response.status
  |> should.equal(404)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>There's nothing here</h1>")
}

pub fn entity_too_large_test() {
  let response = router.handle_request(testing.get("/entity-too-large", []))

  response.status
  |> should.equal(413)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  let assert True =
    response
    |> testing.string_body
    |> string.contains("<h1>Request entity too large</h1>")
}
