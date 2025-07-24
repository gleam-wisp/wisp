import gleam/http
import gleam/string
import wisp/simulate
import working_with_form_data/app/router

pub fn view_form_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert response
    |> simulate.read_body
    |> string.contains("<form method='post'>")
    == True
}

pub fn submit_wrong_content_type_test() {
  let response = router.handle_request(simulate.browser_request(http.Post, "/"))

  assert response.status == 415

  assert response.headers
    == [
      #("accept", "application/x-www-form-urlencoded, multipart/form-data"),
      #("content-type", "text/plain"),
    ]
}

pub fn submit_missing_parameters_test() {
  // The `METHOD_form` functions are used to create a request with a
  // `x-www-form-urlencoded` body, with the appropriate `content-type` header.
  let response =
    simulate.browser_request(http.Post, "/")
    |> simulate.form_body([])
    |> router.handle_request()

  assert response.status == 400
}

pub fn submit_successful_test() {
  let response =
    simulate.browser_request(http.Post, "/")
    |> simulate.form_body([#("title", "Captain"), #("name", "Caveman")])
    |> router.handle_request()

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert simulate.read_body(response) == "Hi, Captain Caveman!"
}
