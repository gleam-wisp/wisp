import gleam/crypto
import gleam/list
import gleam/string
import wisp
import wisp/testing
import working_with_cookies/app/router

pub fn home_not_logged_in_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 303

  assert response.headers == [#("location", "/session")]
}

pub fn home_logged_in_test() {
  let response =
    testing.get("/", [])
    |> testing.set_cookie("id", "Tim", wisp.Signed)
    |> router.handle_request

  assert response.status == 200

  assert response
    |> testing.string_body
    |> string.contains("Hello, Tim!")
    == True
}

pub fn new_session_test() {
  let response = router.handle_request(testing.get("/session", []))

  assert response.status == 200

  assert response
    |> testing.string_body
    |> string.contains("Log in")
    == True
}

pub fn create_session_test() {
  let request = testing.post_form("/session", [], [#("name", "Tim")])
  let response = router.handle_request(request)

  assert response.status == 303

  let assert Ok(cookie) = list.key_find(response.headers, "set-cookie")

  let signed = wisp.sign_message(request, <<"Tim":utf8>>, crypto.Sha512)
  assert string.starts_with(cookie, "id=" <> signed) == True
}
