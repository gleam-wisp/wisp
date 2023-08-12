import gleeunit
import gleeunit/should
import wisp/testing
import app/router

pub fn main() {
  gleeunit.main()
}

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request)

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html")])

  response
  |> testing.string_body
  |> should.equal("Hello, Joe!")
}

pub fn post_home_page_test() {
  let request = testing.post("/", [], "a body")
  let response = router.handle_request(request)
  response.status
  |> should.equal(405)
}

pub fn page_not_found_test() {
  let request = testing.get("/nothing-here", [])
  let response = router.handle_request(request)
  response.status
  |> should.equal(404)
}

pub fn get_comments_test() {
  let request = testing.get("/comments", [])
  let response = router.handle_request(request)
  response.status
  |> should.equal(200)
}

pub fn post_comments_test() {
  let request = testing.post("/comments", [], "")
  let response = router.handle_request(request)
  response.status
  |> should.equal(201)
}

pub fn delete_comments_test() {
  let request = testing.delete("/comments", [], "")
  let response = router.handle_request(request)
  response.status
  |> should.equal(405)
}

pub fn get_comment_test() {
  let request = testing.get("/comments/123", [])
  let response = router.handle_request(request)
  response.status
  |> should.equal(200)
  response
  |> testing.string_body
  |> should.equal("Comment with id 123")
}

pub fn delete_comment_test() {
  let request = testing.delete("/comments/123", [], "")
  let response = router.handle_request(request)
  response.status
  |> should.equal(405)
}
