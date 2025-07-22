import gleam/http
import gleam/json
import wisp/simulate
import working_with_json/app/router

pub fn get_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 405
}

pub fn submit_wrong_content_type_test() {
  let response = router.handle_request(simulate.browser_request(http.Post, "/"))

  assert response.status == 415

  assert response.headers == [#("accept", "application/json")]
}

pub fn submit_missing_parameters_test() {
  let json = json.object([#("name", json.string("Joe"))])

  // The `METHOD_json` functions are used to create a request with a JSON body,
  // with the appropriate `content-type` header.
  let response =
    simulate.browser_request(http.Post, "/")
    |> simulate.json_body(json)
    |> router.handle_request()

  assert response.status == 422
}

pub fn submit_successful_test() {
  let json =
    json.object([#("name", json.string("Joe")), #("is-cool", json.bool(True))])
  let response =
    simulate.browser_request(http.Post, "/")
    |> simulate.json_body(json)
    |> router.handle_request()

  assert response.status == 201

  assert response.headers
    == [#("content-type", "application/json; charset=utf-8")]

  assert simulate.read_body(response)
    == "{\"name\":\"Joe\",\"is-cool\":true,\"saved\":true}"
}
