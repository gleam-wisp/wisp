import app/router
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn get_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(405)
}

pub fn post_wrong_content_type_test() {
  let response = router.handle_request(testing.post("/", [], ""))

  response.status
  |> should.equal(415)

  response.headers
  |> should.equal([#("accept", "text/csv")])
}

pub fn post_successful_test() {
  let csv = "name,is-cool\nJoe,true\nJosé,true\n"

  let response =
    testing.post("/", [], csv)
    |> testing.set_header("content-type", "text/csv")
    |> router.handle_request()

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/csv")])

  response
  |> testing.string_body
  |> should.equal("headers,row-count\n\"name,is-cool\",2")
}
