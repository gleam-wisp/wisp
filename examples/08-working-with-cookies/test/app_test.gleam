import app/router
import gleam/crypto
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import wisp
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn home_not_logged_in_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(303)

  response.headers
  |> should.equal([#("location", "/session")])
}

pub fn home_logged_in_test() {
  let response =
    testing.get("/", [])
    |> testing.set_cookie("id", "Tim", wisp.Signed)
    |> router.handle_request

  response.status
  |> should.equal(200)

  response
  |> testing.string_body
  |> string.contains("Hello, Tim!")
  |> should.equal(True)
}

pub fn new_session_test() {
  let response = router.handle_request(testing.get("/session", []))

  response.status
  |> should.equal(200)

  response
  |> testing.string_body
  |> string.contains("Log in")
  |> should.equal(True)
}

pub fn create_session_test() {
  let request = testing.post_form("/session", [], [#("name", "Tim")])
  let response = router.handle_request(request)

  response.status
  |> should.equal(303)

  let assert Ok(cookie) = list.key_find(response.headers, "set-cookie")

  let signed = wisp.sign_message(request, <<"Tim":utf8>>, crypto.Sha512)
  cookie
  |> string.starts_with("id=" <> signed)
  |> should.equal(True)
}
