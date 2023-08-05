import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/list
import gleam/string_builder
import gleeunit
import gleeunit/should
import wisp

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

pub fn path_segments_test() {
  request.new()
  |> request.set_path("/one/two/three")
  |> wisp.path_segments
  |> should.equal(["one", "two", "three"])
}

pub fn method_override_test() {
  // These methods can be overridden to
  use method <- list.each([http.Put, http.Delete, http.Patch])

  let request =
    request.new()
    |> request.set_method(method)
    |> request.set_query([#("_method", http.method_to_string(method))])
  request
  |> wisp.method_override
  |> should.equal(request.set_method(request, method))
}

pub fn method_override_unacceptable_unoriginal_method_test() {
  // These methods are not allowed to be overridden
  use method <- list.each([
    http.Head,
    http.Put,
    http.Delete,
    http.Trace,
    http.Connect,
    http.Options,
    http.Patch,
    http.Other("MYSTERY"),
  ])

  let request =
    request.new()
    |> request.set_method(method)
    |> request.set_query([#("_method", "DELETE")])
  request
  |> wisp.method_override
  |> should.equal(request)
}

pub fn method_override_unacceptable_target_method_test() {
  // These methods are not allowed to be overridden to
  use method <- list.each([
    http.Get,
    http.Head,
    http.Trace,
    http.Connect,
    http.Options,
    http.Other("MYSTERY"),
  ])

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_query([#("_method", http.method_to_string(method))])
  request
  |> wisp.method_override
  |> should.equal(request)
}
