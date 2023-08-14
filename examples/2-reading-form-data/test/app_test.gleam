import gleeunit
import gleeunit/should
import gleam/string
import wisp/testing
import gleam/http/request
import app/router

pub fn main() {
  gleeunit.main()
}

pub fn view_form_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html")])

  response
  |> testing.string_body
  |> string.contains("<form method='post'>")
  |> should.equal(True)
}

pub fn submit_wrong_content_type_test() {
  let response = router.handle_request(testing.post("/", [], ""))

  response.status
  |> should.equal(415)

  response.headers
  |> should.equal([
    #("accept", "application/x-www-form-urlencoded, multipart/form-data"),
  ])
}

pub fn submit_missing_parameters_test() {
  let response =
    testing.post("/", [], "")
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> router.handle_request()

  response.status
  |> should.equal(400)
}

pub fn submit_successful_test() {
  let response =
    testing.post("/", [], "title=Captain&name=Caveman")
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> router.handle_request()

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html")])

  response
  |> testing.string_body
  |> should.equal("Hi, Captain Caveman!")
}
