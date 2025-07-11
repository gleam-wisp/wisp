import wisp/testing
import working_with_other_formats/app/router

pub fn get_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 405
}

pub fn post_wrong_content_type_test() {
  let response = router.handle_request(testing.post("/", [], ""))

  assert response.status == 415

  assert response.headers == [#("accept", "text/csv")]
}

pub fn post_successful_test() {
  let csv = "name,is-cool\nJoe,true\nJosé,true\n"

  let response =
    testing.post("/", [], csv)
    |> testing.set_header("content-type", "text/csv")
    |> router.handle_request()

  assert response.status == 200

  assert response.headers == [#("content-type", "text/csv")]

  assert testing.string_body(response)
    == "headers,row-count\n\"name,is-cool\",2\n"
}
