import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/list
import gleam/string_builder
import gleeunit
import gleeunit/should
import simplifile
import wisp

pub fn main() {
  gleeunit.main()
}

pub fn ok_test() {
  wisp.ok()
  |> should.equal(Response(200, [], wisp.Empty))
}

pub fn created_test() {
  wisp.created()
  |> should.equal(Response(201, [], wisp.Empty))
}

pub fn accepted_test() {
  wisp.accepted()
  |> should.equal(Response(202, [], wisp.Empty))
}

pub fn no_content_test() {
  wisp.no_content()
  |> should.equal(Response(204, [], wisp.Empty))
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
  let request = wisp.test_request(<<>>)

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

pub fn require_method_test() {
  {
    let request = request.new()
    use <- wisp.require_method(request, http.Get)
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn require_method_invalid_test() {
  {
    let request = request.set_method(request.new(), http.Post)
    use <- wisp.require_method(request, http.Get)
    panic as "should be unreachable"
  }
  |> should.equal(wisp.method_not_allowed([http.Get]))
}

pub fn require_ok_test() {
  {
    use x <- wisp.require(Ok(1))
    x
    |> should.equal(1)
    wisp.accepted()
  }
  |> should.equal(wisp.accepted())
}

pub fn require_error_test() {
  {
    use _ <- wisp.require(Error(1))
    panic as "should be unreachable"
  }
  |> should.equal(wisp.bad_request())
}

pub fn require_string_body_test() {
  {
    let request = wisp.test_request(<<"Hello, Joe!":utf8>>)
    use body <- wisp.require_string_body(request)
    body
    |> should.equal("Hello, Joe!")
    wisp.accepted()
  }
  |> should.equal(wisp.accepted())
}

pub fn require_string_body_invalid_test() {
  {
    let request = wisp.test_request(<<254>>)
    use _ <- wisp.require_string_body(request)
    panic as "should be unreachable"
  }
  |> should.equal(wisp.bad_request())
}

pub fn rescue_crashes_error_test() {
  {
    use <- wisp.rescue_crashes
    panic as "we need to crash to test the middleware"
  }
  |> should.equal(wisp.internal_server_error())
}

pub fn rescue_crashes_ok_test() {
  {
    use <- wisp.rescue_crashes
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn serve_static_test() {
  let request =
    wisp.test_request(<<>>)
    |> request.set_path("/stuff/README.md")
  let response = {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "text/markdown")])
  response.body
  |> should.equal(wisp.File("./README.md"))
}

pub fn serve_static_under_has_no_trailing_slash_test() {
  let request =
    wisp.test_request(<<>>)
    |> request.set_path("/stuff/README.md")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: "./")
    wisp.ok()
  }
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "text/markdown")])
  response.body
  |> should.equal(wisp.File("./README.md"))
}

pub fn serve_static_from_has_no_trailing_slash_test() {
  let request =
    wisp.test_request(<<>>)
    |> request.set_path("/stuff/README.md")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: ".")
    wisp.ok()
  }
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "text/markdown")])
  response.body
  |> should.equal(wisp.File("./README.md"))
}

pub fn serve_static_not_found_test() {
  let request =
    wisp.test_request(<<>>)
    |> request.set_path("/stuff/credit_card_details.txt")
  {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn serve_static_go_up_test() {
  let request =
    wisp.test_request(<<>>)
    |> request.set_path("/../README.md")
  {
    use <- wisp.serve_static(request, under: "/stuff", from: "./src/")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn temporary_file_test() {
  // Create tmp files for a first request
  let request1 = wisp.test_request(<<>>)
  let assert Ok(request1_file1) = wisp.new_temporary_file(request1)
  let assert Ok(request1_file2) = wisp.new_temporary_file(request1)

  // The files exist
  request1_file1
  |> should.not_equal(request1_file2)
  let assert Ok(_) = simplifile.read(request1_file1)
  let assert Ok(_) = simplifile.read(request1_file2)

  // Create tmp files for a second request
  let request2 = wisp.test_request(<<>>)
  let assert Ok(request2_file1) = wisp.new_temporary_file(request2)
  let assert Ok(request2_file2) = wisp.new_temporary_file(request2)

  // The files exist
  request2_file1
  |> should.not_equal(request1_file2)
  let assert Ok(_) = simplifile.read(request2_file1)
  let assert Ok(_) = simplifile.read(request2_file2)

  // Delete the files for the first request
  let assert Ok(_) = wisp.delete_temporary_files(request1)

  // They no longer exist
  let assert Error(simplifile.Enoent) = simplifile.read(request1_file1)
  let assert Error(simplifile.Enoent) = simplifile.read(request1_file2)

  // The files for the second request still exist
  let assert Ok(_) = simplifile.read(request2_file1)
  let assert Ok(_) = simplifile.read(request2_file2)

  // Delete the files for the first request
  let assert Ok(_) = wisp.delete_temporary_files(request2)

  // They no longer exist
  let assert Error(simplifile.Enoent) = simplifile.read(request2_file1)
  let assert Error(simplifile.Enoent) = simplifile.read(request2_file2)
}
