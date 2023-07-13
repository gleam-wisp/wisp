import gleeunit
import gleeunit/should
import action.{Context}
import gleam/http/request.{Request}
import gleam/http.{Get, Method}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
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
}

// TODO: move this to a helper module
pub fn request(method: Method, path: String) -> Request(BitString) {
  request.new()
  |> request.set_method(method)
  |> request.set_path(path)
  |> request.set_body(<<>>)
}
