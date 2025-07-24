import gleam/http
import wisp/simulate
import working_with_other_formats/app/router

pub fn get_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 405
}

pub fn post_wrong_content_type_test() {
  let response = router.handle_request(simulate.browser_request(http.Post, "/"))

  assert response.status == 415

  assert response.headers
    == [#("accept", "text/csv"), #("content-type", "text/plain")]
}

pub fn post_successful_test() {
  let csv = "name,is-cool\nJoe,true\nJosé,true\n"

  let response =
    simulate.browser_request(http.Post, "/")
    |> simulate.string_body(csv)
    |> simulate.header("content-type", "text/csv")
    |> router.handle_request()

  assert response.status == 200

  assert response.headers == [#("content-type", "text/csv")]

  assert simulate.read_body(response)
    == "headers,row-count\n\"name,is-cool\",2\n"
}
