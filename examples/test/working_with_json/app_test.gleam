import gleam/json
import wisp/testing
import working_with_json/app/router

pub fn get_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 405
}

pub fn submit_wrong_content_type_test() {
  let response = router.handle_request(testing.post("/", [], ""))

  assert response.status == 415

  assert response.headers == [#("accept", "application/json")]
}

pub fn submit_missing_parameters_test() {
  let json = json.object([#("name", json.string("Joe"))])

  // The `METHOD_json` functions are used to create a request with a JSON body,
  // with the appropriate `content-type` header.
  let response =
    testing.post_json("/", [], json)
    |> router.handle_request()

  assert response.status == 422
}

pub fn submit_successful_test() {
  let json =
    json.object([#("name", json.string("Joe")), #("is-cool", json.bool(True))])
  let response =
    testing.post_json("/", [], json)
    |> router.handle_request()

  assert response.status == 201

  assert response.headers
    == [#("content-type", "application/json; charset=utf-8")]

  assert testing.string_body(response)
    == "{\"name\":\"Joe\",\"is-cool\":true,\"saved\":true}"
}
