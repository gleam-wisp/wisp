import gleeunit
import gleeunit/should
import action/router
import action/web.{Context}
import action/database
import gleam/string
import gleam/http/request
import gleam/http.{Get, Method, Post}
import gleam/string_builder
import framework

pub fn main() {
  gleeunit.main()
}

// TODO: move this to a helper module
pub fn test_context(next: fn(Context) -> t) -> t {
  use db <- database.with_connection(":memory:")
  next(Context(db: db))
}

// TODO: move this to a helper module
pub fn request(method: Method, path: String) -> framework.Request {
  request.new()
  |> request.set_method(method)
  |> request.set_path(path)
  |> request.set_body(framework.test_connection(<<>>))
}

// TODO: move this to a helper module
pub fn content(response: framework.Response) -> String {
  response.body
  |> framework.body_to_string_builder
  |> string_builder.to_string
}

pub fn page_not_found_test() {
  use context <- test_context()
  let request = request(Get, "/not-found")
  let response = router.handle_request(request, context)

  response.status
  |> should.equal(404)
}

pub fn home_page_test() {
  use context <- test_context()
  let request = request(Get, "/")
  let response = router.handle_request(request, context)

  response.status
  |> should.equal(200)

  content(response)
  |> string.contains("<h1>Hello, Joe!</h1>")
  |> should.be_true
}

pub fn home_page_post_test() {
  use context <- test_context()
  let request = request(Post, "/")
  let response = router.handle_request(request, context)

  response.status
  |> should.equal(405)
}
