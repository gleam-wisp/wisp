import gleeunit
import gleeunit/should
import wisp
import gleam/http
import gleam/http/response.{Response}
import gleam/http/request
import gleam/string_builder

pub fn main() {
  gleeunit.main()
}

pub fn internal_server_error_test() {
  wisp.internal_server_error()
  |> should.equal(Response(500, [], wisp.Empty))
}

pub fn entity_too_large_test() {
  wisp.entity_too_large()
  |> should.equal(Response(413, [], wisp.Empty))
}

pub fn bad_request_test() {
  wisp.bad_request()
  |> should.equal(Response(400, [], wisp.Empty))
}

pub fn not_found_test() {
  wisp.not_found()
  |> should.equal(Response(404, [], wisp.Empty))
}

pub fn method_not_allowed_test() {
  wisp.method_not_allowed([http.Get, http.Patch, http.Delete])
  |> should.equal(Response(405, [#("allow", "DELETE, GET, PATCH")], wisp.Empty))
}

pub fn html_response_test() {
  let body = string_builder.from_string("Hello, world!")
  let response = wisp.html_response(body, 200)
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "text/html")])
  response.body
  |> wisp.body_to_string_builder
  |> should.equal(body)
}

pub fn html_body_test() {
  let body = string_builder.from_string("Hello, world!")
  let response =
    wisp.method_not_allowed([http.Get])
    |> wisp.html_body(body)
  response.status
  |> should.equal(405)
  response.headers
  |> should.equal([#("allow", "GET"), #("content-type", "text/html")])
  response.body
  |> wisp.body_to_string_builder
  |> should.equal(body)
}

pub fn set_get_max_body_size_test() {
  let request =
    request.new()
    |> request.set_body(wisp.test_connection(<<>>))

  request
  |> wisp.get_max_body_size
  |> should.equal(8_000_000)

  request
  |> wisp.set_max_body_size(10)
  |> wisp.get_max_body_size
  |> should.equal(10)
}

pub fn set_get_max_files_size_test() {
  let request =
    request.new()
    |> request.set_body(wisp.test_connection(<<>>))

  request
  |> wisp.get_max_files_size
  |> should.equal(32_000_000)

  request
  |> wisp.set_max_files_size(10)
  |> wisp.get_max_files_size
  |> should.equal(10)
}

pub fn set_get_read_chunk_size_test() {
  let request =
    request.new()
    |> request.set_body(wisp.test_connection(<<>>))

  request
  |> wisp.get_read_chunk_size
  |> should.equal(1_000_000)

  request
  |> wisp.set_read_chunk_size(10)
  |> wisp.get_read_chunk_size
  |> should.equal(10)
}
