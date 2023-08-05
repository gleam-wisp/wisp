import gleeunit
import gleeunit/should
import wisp
import gleam/http
import gleam/http/response.{Response}

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
