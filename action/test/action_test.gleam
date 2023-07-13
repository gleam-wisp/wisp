import gleeunit
import gleeunit/should
import action
import framework.{Context}
import gleam/string
import gleam/http/request.{Request}
import gleam/http.{Get, Method, Post}
import gleam/string_builder

pub fn main() {
  gleeunit.main()
}

pub fn page_not_found_test() {
  let request = request(Get, "/not-found")
  let context = Context(request: request, state: Nil)
  let response = action.handle_request(context)

  response.status
  |> should.equal(404)
}

pub fn home_page_test() {
  let request = request(Get, "/")
  let context = Context(request: request, state: Nil)
  let response = action.handle_request(context)

  response.status
  |> should.equal(200)

  response.body
  |> string_builder.to_string
  |> string.contains("<h1>Hello, Joe!</h1>")
  |> should.be_true
}

pub fn home_page_post_test() {
  let request = request(Post, "/")
  let context = Context(request: request, state: Nil)
  let response = action.handle_request(context)

  response.status
  |> should.equal(405)
}

// TODO: move this to a helper module
pub fn request(method: Method, path: String) -> Request(BitString) {
  request.new()
  |> request.set_method(method)
  |> request.set_path(path)
  |> request.set_body(<<>>)
}
