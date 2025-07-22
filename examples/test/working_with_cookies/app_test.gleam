import gleam/crypto
import gleam/http
import gleam/list
import gleam/string
import wisp
import wisp/simulate
import working_with_cookies/app/router

pub fn home_not_logged_in_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 303

  assert response.headers == [#("location", "/session")]
}

pub fn home_logged_in_test() {
  let response =
    simulate.browser_request(http.Get, "/")
    |> simulate.cookie("id", "Tim", wisp.Signed)
    |> router.handle_request

  assert response.status == 200

  assert response
    |> simulate.read_body
    |> string.contains("Hello, Tim!")
    == True
}

pub fn new_session_test() {
  let response =
    router.handle_request(simulate.browser_request(http.Get, "/session"))

  assert response.status == 200

  assert response
    |> simulate.read_body
    |> string.contains("Log in")
    == True
}

pub fn create_session_test() {
  let request =
    simulate.browser_request(http.Post, "/session")
    |> simulate.form_body([#("name", "Tim")])
  let response = router.handle_request(request)

  assert response.status == 303

  let assert Ok(cookie) = list.key_find(response.headers, "set-cookie")

  let signed = wisp.sign_message(request, <<"Tim":utf8>>, crypto.Sha512)
  assert string.starts_with(cookie, "id=" <> signed) == True
}
