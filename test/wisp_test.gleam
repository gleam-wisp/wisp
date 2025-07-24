import exception
import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string
import gleam/string_tree
import gleeunit
import helper
import simplifile
import wisp
import wisp/internal
import wisp/simulate

pub fn main() {
  wisp.configure_logger()
  gleeunit.main()
}

fn form_handler(
  request: wisp.Request,
  callback: fn(wisp.FormData) -> anything,
) -> wisp.Response {
  use form <- wisp.require_form(request)
  callback(form)
  wisp.ok()
}

fn json_handler(
  request: wisp.Request,
  callback: fn(Dynamic) -> anything,
) -> wisp.Response {
  use json <- wisp.require_json(request)
  callback(json)
  wisp.ok()
}

fn static_file_handler(request: wisp.Request) -> wisp.Response {
  use <- wisp.serve_static(request, under: "/", from: "./test")
  wisp.ok()
}

pub fn ok_test() {
  assert wisp.ok()
    == Response(200, [#("content-type", "text/plain")], wisp.Text("OK"))
}

pub fn created_test() {
  assert wisp.created()
    == Response(201, [#("content-type", "text/plain")], wisp.Text("Created"))
}

pub fn accepted_test() {
  assert wisp.accepted()
    == Response(202, [#("content-type", "text/plain")], wisp.Text("Accepted"))
}

pub fn no_content_test() {
  assert wisp.no_content() == Response(204, [], wisp.Text(""))
}

pub fn redirect_test() {
  assert wisp.redirect(to: "https://example.com/wibble")
    == Response(
      303,
      [
        #("location", "https://example.com/wibble"),
        #("content-type", "text/plain"),
      ],
      wisp.Text("You are being redirected: https://example.com/wibble"),
    )
}

pub fn moved_permanently_test() {
  assert wisp.permanent_redirect(to: "https://example.com/wobble")
    == Response(
      308,
      [
        #("location", "https://example.com/wobble"),
        #("content-type", "text/plain"),
      ],
      wisp.Text("You are being redirected: https://example.com/wobble"),
    )
}

pub fn internal_server_error_test() {
  assert wisp.internal_server_error()
    == Response(
      500,
      [#("content-type", "text/plain")],
      wisp.Text("Internal server error"),
    )
}

pub fn content_too_large_test() {
  assert wisp.content_too_large()
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )
}

pub fn bad_request_test() {
  assert wisp.bad_request("")
    == Response(
      400,
      [#("content-type", "text/plain")],
      wisp.Text("Bad request"),
    )
}

pub fn bad_request_with_message_test() {
  assert wisp.bad_request("On fire")
    == Response(
      400,
      [#("content-type", "text/plain")],
      wisp.Text("Bad request: On fire"),
    )
}

pub fn not_found_test() {
  assert wisp.not_found()
    == Response(404, [#("content-type", "text/plain")], wisp.Text("Not found"))
}

pub fn method_not_allowed_test() {
  assert wisp.method_not_allowed([http.Get, http.Patch, http.Delete])
    == Response(
      405,
      [#("allow", "DELETE, GET, PATCH")],
      wisp.Text("Method not allowed"),
    )
}

pub fn unsupported_media_type_test() {
  assert wisp.unsupported_media_type(accept: ["application/json", "text/plain"])
    == Response(
      415,
      [
        #("accept", "application/json, text/plain"),
        #("content-type", "text/plain"),
      ],
      wisp.Text("Unsupported media type"),
    )
}

pub fn unprocessable_content_test() {
  assert wisp.unprocessable_content()
    == Response(
      422,
      [#("content-type", "text/plain")],
      wisp.Text("Unprocessable content"),
    )
}

pub fn json_response_test() {
  let body = "{\"one\":1,\"two\":2}"
  let response = wisp.json_response(body, 201)
  assert response.status == 201
  assert response.headers
    == [#("content-type", "application/json; charset=utf-8")]
  assert simulate.read_body(response) == "{\"one\":1,\"two\":2}"
}

pub fn html_response_test() {
  let body = "Hello, world!"
  let response = wisp.html_response(body, 200)
  assert response.status == 200
  assert response.headers == [#("content-type", "text/html; charset=utf-8")]
  assert simulate.read_body(response) == "Hello, world!"
}

pub fn html_body_test() {
  let body = "Hello, world!"
  let response =
    wisp.method_not_allowed([http.Get])
    |> wisp.html_body(body)
  assert response.status == 405
  assert response.headers
    == [
      #("allow", "GET"),
      #("content-type", "text/html; charset=utf-8"),
    ]
  assert simulate.read_body(response) == "Hello, world!"
}

pub fn random_string_test() {
  let count = 10_000
  let new = fn(_) {
    let random = wisp.random_string(64)
    assert string.length(random) == 64
    random
  }

  assert list.repeat(Nil, count)
    |> list.map(new)
    |> set.from_list
    |> set.size
    == count
}

pub fn set_get_secret_key_base_test() {
  let request = simulate.request(http.Get, "/")
  let valid = wisp.random_string(64)
  let too_short = wisp.random_string(63)

  assert wisp.get_secret_key_base(request) == simulate.default_secret_key_base

  assert request
    |> wisp.set_secret_key_base(valid)
    |> wisp.get_secret_key_base
    == valid

  // Panics if the key is too short
  let assert Error(_) =
    exception.rescue(fn() { wisp.set_secret_key_base(request, too_short) })
}

pub fn set_get_max_body_size_test() {
  let request = simulate.request(http.Get, "/")

  assert wisp.get_max_body_size(request) == 8_000_000

  assert request
    |> wisp.set_max_body_size(10)
    |> wisp.get_max_body_size
    == 10
}

pub fn set_get_max_files_size_test() {
  let request = simulate.request(http.Get, "/")

  assert wisp.get_max_files_size(request) == 32_000_000

  assert request
    |> wisp.set_max_files_size(10)
    |> wisp.get_max_files_size
    == 10
}

pub fn set_get_read_chunk_size_test() {
  let request = simulate.request(http.Get, "/")

  assert wisp.get_read_chunk_size(request) == 1_000_000

  assert request
    |> wisp.set_read_chunk_size(10)
    |> wisp.get_read_chunk_size
    == 10
}

pub fn path_segments_test() {
  assert request.new()
    |> request.set_path("/one/two/three")
    |> wisp.path_segments
    == ["one", "two", "three"]
}

pub fn method_override_test() {
  // These methods can be overridden to
  use method <- list.each([http.Put, http.Delete, http.Patch])

  let request =
    request.new()
    |> request.set_method(method)
    |> request.set_query([#("_method", http.method_to_string(method))])
  assert wisp.method_override(request) == request.set_method(request, method)
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
  assert wisp.method_override(request) == request
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
  assert wisp.method_override(request) == request
}

pub fn require_method_test() {
  let response = {
    let request = request.new()
    use <- wisp.require_method(request, http.Get)
    wisp.ok()
  }

  assert response == wisp.ok()
}

pub fn require_method_invalid_test() {
  let response = {
    let request = request.set_method(request.new(), http.Post)
    use <- wisp.require_method(request, http.Get)
    panic as "should be unreachable"
  }
  assert response == wisp.method_not_allowed([http.Get])
}

pub fn require_string_body_test() {
  let response = {
    let request =
      simulate.request(http.Post, "/")
      |> simulate.string_body("Hello, Joe!")
    use body <- wisp.require_string_body(request)
    assert body == "Hello, Joe!"
    wisp.accepted()
  }
  assert response == wisp.accepted()
}

pub fn require_string_body_invalid_test() {
  let response = {
    let request =
      simulate.request(http.Post, "/")
      |> simulate.bit_array_body(<<254>>)
    use _ <- wisp.require_string_body(request)
    panic as "should be unreachable"
  }
  assert response == wisp.bad_request("Invalid UTF-8")
}

pub fn rescue_crashes_error_test() {
  use <- helper.disable_logger()

  let response = {
    use <- wisp.rescue_crashes
    panic as "we need to crash to test the middleware"
  }
  assert response == wisp.internal_server_error()
}

pub fn rescue_crashes_ok_test() {
  let response = {
    use <- wisp.rescue_crashes
    wisp.ok()
  }
  assert response == wisp.ok()
}

pub fn serve_static_test() {
  let handler = fn(request) {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }

  // Get a text file
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.txt")
    |> handler
  let assert Ok(file_info) = simplifile.file_info("test/fixture.txt")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.txt", offset: 0, limit: option.None)

  // Get a json file
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.json")
    |> handler
  let assert Ok(file_info) = simplifile.file_info("test/fixture.json")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "application/json; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.json", offset: 0, limit: option.None)

  // Get some other file
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.dat")
    |> handler
  let assert Ok(file_info) = simplifile.file_info("test/fixture.dat")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "application/octet-stream"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.dat", offset: 0, limit: option.None)

  // Get something not handled by the static file server
  let response =
    simulate.request(http.Get, "/stuff/this-does-not-exist")
    |> handler
  assert response.status == 200
  assert response.headers == [#("content-type", "text/plain")]
  assert response.body == wisp.Text("OK")
}

pub fn serve_static_directory_request_test() {
  let handler = fn(request) {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }

  assert // confirm test directory is a directory
  result.unwrap(simplifile.is_directory("./test"), False)

  // Get a directory
  let response =
    simulate.request(http.Get, "/stuff/test")
    |> handler
  assert response.status == 200
  assert response.headers == [#("content-type", "text/plain")]
  assert response.body == wisp.Text("OK")
}

pub fn serve_static_under_has_no_trailing_slash_test() {
  let request =
    simulate.request(http.Get, "/")
    |> request.set_path("/stuff/test/fixture.txt")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: "./")
    wisp.ok()
  }
  let assert Ok(file_info) = simplifile.file_info("test/fixture.txt")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.txt", offset: 0, limit: option.None)
}

pub fn serve_static_from_has_no_trailing_slash_test() {
  let request =
    simulate.request(http.Get, "/")
    |> request.set_path("/stuff/test/fixture.txt")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: ".")
    wisp.ok()
  }
  let assert Ok(file_info) = simplifile.file_info("test/fixture.txt")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.txt", offset: 0, limit: option.None)
}

pub fn serve_static_not_found_test() {
  let request =
    simulate.request(http.Get, "/")
    |> request.set_path("/stuff/credit_card_details.txt")
  assert {
      use <- wisp.serve_static(request, under: "/stuff", from: "./")
      wisp.ok()
    }
    == wisp.ok()
}

pub fn serve_static_go_up_test() {
  let request =
    simulate.request(http.Get, "/")
    |> request.set_path("/../test/fixture.txt")
  assert {
      use <- wisp.serve_static(request, under: "/stuff", from: "./src/")
      wisp.ok()
    }
    == wisp.ok()
}

pub fn serve_static_etags_returns_304_test() {
  let handler = fn(request) {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }

  // Get a text file without any headers
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.txt")
    |> handler
  let assert Ok(file_info) = simplifile.file_info("test/fixture.txt")
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.txt", offset: 0, limit: option.None)

  // Get a text file with outdated if-none-match header
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.txt")
    |> simulate.header("if-none-match", "invalid-etag")
    |> handler

  assert response.status == 200
  assert response.headers
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", etag),
    ]
  assert response.body
    == wisp.File("./test/fixture.txt", offset: 0, limit: option.None)

  // Get a text file with current etag in if-none-match header
  let response =
    simulate.request(http.Get, "/stuff/test/fixture.txt")
    |> simulate.header("if-none-match", etag)
    |> handler

  assert response.status == 304
  assert response.headers == [#("etag", etag)]
  assert response.body == wisp.Text("")
}

pub fn serve_static_range_start_test() {
  let response =
    simulate.request(http.Get, "/fixture.txt")
    |> simulate.header("range", "bytes=2-")
    |> static_file_handler

  assert response.status == 206
  assert response.headers
    |> list.key_set("etag", "")
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", ""),
      #("content-length", "36"),
      #("accept-ranges", "bytes"),
      #("content-range", "bytes 2-37/38"),
    ]
  assert simulate.read_body(response) == "llo, Joe! 👨‍👩‍👧‍👦\n"
}

pub fn serve_static_range_start_limit_test() {
  let response =
    simulate.request(http.Get, "/fixture.txt")
    |> simulate.header("range", "bytes=2-15")
    |> static_file_handler

  assert response.status == 206
  assert response.headers
    |> list.key_set("etag", "")
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", ""),
      #("content-length", "14"),
      #("accept-ranges", "bytes"),
      #("content-range", "bytes 2-15/38"),
    ]
  assert simulate.read_body(response) == "llo, Joe! 👨"
}

pub fn serve_static_range_negative_test() {
  let response =
    simulate.request(http.Get, "/fixture.txt")
    |> simulate.header("range", "bytes=-26")
    |> static_file_handler

  assert response.status == 206
  assert response.headers
    |> list.key_set("etag", "")
    == [
      #("content-type", "text/plain; charset=utf-8"),
      #("etag", ""),
      #("content-length", "26"),
      #("accept-ranges", "bytes"),
      #("content-range", "bytes 12-37/38"),
    ]
  assert simulate.read_body(response) == "👨‍👩‍👧‍👦\n"
}

pub fn serve_static_range_limit_larger_than_content_test() {
  let response =
    simulate.request(http.Get, "/fixture.txt")
    |> simulate.header("range", "bytes=2-100")
    |> static_file_handler
  assert response.status == 416
}

pub fn serve_static_range_header_invalid_test() {
  // The range values are is backwards
  let response =
    simulate.request(http.Get, "/fixture.txt")
    |> simulate.header("range", "bytes=6-4")
    |> static_file_handler

  assert response.status == 416
}

pub fn temporary_file_test() {
  // Create tmp files for a first request
  let request1 = simulate.request(http.Get, "/")
  let assert Ok(request1_file1) = wisp.new_temporary_file(request1)
  let assert Ok(request1_file2) = wisp.new_temporary_file(request1)

  assert // The files exist
    request1_file1 != request1_file2
  let assert Ok(_) = simplifile.read(request1_file1)
  let assert Ok(_) = simplifile.read(request1_file2)

  // Create tmp files for a second request
  let request2 = simulate.request(http.Get, "/")
  let assert Ok(request2_file1) = wisp.new_temporary_file(request2)
  let assert Ok(request2_file2) = wisp.new_temporary_file(request2)

  assert // The files exist
    request2_file1 != request1_file2
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

pub fn require_content_type_test() {
  let response = {
    let request =
      simulate.request(http.Get, "/")
      |> simulate.header("content-type", "text/plain")
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  assert response == wisp.ok()
}

pub fn require_content_type_charset_test() {
  let response = {
    let request =
      simulate.request(http.Get, "/")
      |> simulate.header("content-type", "text/plain; charset=utf-8")
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  assert response == wisp.ok()
}

pub fn require_content_type_missing_test() {
  let response = {
    let request = simulate.request(http.Get, "/")
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  assert response == wisp.unsupported_media_type(["text/plain"])
}

pub fn require_content_type_invalid_test() {
  let response = {
    let request =
      simulate.request(http.Get, "/")
      |> simulate.header("content-type", "text/plain")
    use <- wisp.require_content_type(request, "text/html")
    panic as "should be unreachable"
  }
  assert response == wisp.unsupported_media_type(["text/html"])
}

pub fn json_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("{\"one\":1,\"two\":2}")
    |> request.set_header("content-type", "application/json")
    |> json_handler(fn(json) {
      assert json
        == dynamic.properties([
          #(dynamic.string("one"), dynamic.int(1)),
          #(dynamic.string("two"), dynamic.int(2)),
        ])
    })
    == wisp.ok()
}

pub fn json_wrong_content_type_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("{\"one\":1,\"two\":2}")
    |> request.set_header("content-type", "text/plain")
    |> json_handler(fn(_) { panic as "should be unreachable" })
    == wisp.unsupported_media_type(["application/json"])
}

pub fn json_no_content_type_test() {
  assert json_handler(
      simulate.request(http.Post, "/")
        |> simulate.string_body("{\"one\":1,\"two\":2}"),
      fn(_) { panic as "should be unreachable" },
    )
    == wisp.unsupported_media_type(["application/json"])
}

pub fn json_too_big_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("{\"one\":1,\"two\":2}")
    |> wisp.set_max_body_size(1)
    |> request.set_header("content-type", "application/json")
    |> json_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )
}

pub fn json_syntax_error_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("{\"one\":")
    |> request.set_header("content-type", "application/json")
    |> json_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      400,
      [#("content-type", "text/plain")],
      wisp.Text("Bad request: Invalid JSON"),
    )
}

pub fn urlencoded_form_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("one=1&two=2")
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> form_handler(fn(form) {
      assert form == wisp.FormData([#("one", "1"), #("two", "2")], [])
    })
    == wisp.ok()
}

pub fn urlencoded_form_with_charset_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("one=1&two=2")
    |> request.set_header(
      "content-type",
      "application/x-www-form-urlencoded; charset=UTF-8",
    )
    |> form_handler(fn(form) {
      assert form == wisp.FormData([#("one", "1"), #("two", "2")], [])
    })
    == wisp.ok()
}

pub fn urlencoded_too_big_form_test() {
  assert simulate.request(http.Post, "/")
    |> simulate.string_body("12")
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> wisp.set_max_body_size(1)
    |> form_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )
}

pub fn multipart_form_test() {
  let data =
    "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary\r
Content-Disposition: form-data; name=\"two\"\r
\r
2\r
--theboundary--\r
"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(fn(form) {
      assert form == wisp.FormData([#("one", "1"), #("two", "2")], [])
    })
    == wisp.ok()
}

pub fn multipart_form_too_big_test() {
  let data =
    "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary--\r
"
  assert simulate.request(http.Post, "/")
    |> wisp.set_max_body_size(1)
    |> simulate.string_body(data)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> wisp.set_max_body_size(1)
    |> form_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )
}

pub fn multipart_form_no_boundary_test() {
  let data =
    "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary--\r
"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header("content-type", "multipart/form-data")
    |> form_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      400,
      [#("content-type", "text/plain")],
      wisp.Text("Bad request: Invalid form encoding"),
    )
}

pub fn multipart_form_invalid_format_test() {
  let data = "--theboundary\r\n--theboundary--\r\n"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      400,
      [#("content-type", "text/plain")],
      wisp.Text("Bad request: Unexpected end of request body"),
    )
}

pub fn form_unknown_content_type_test() {
  let data = "one=1&two=2"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header("content-type", "text/form")
    |> form_handler(fn(_) { panic as "should be unreachable" })
    == Response(
      415,
      [
        #("accept", "application/x-www-form-urlencoded, multipart/form-data"),
        #("content-type", "text/plain"),
      ],
      wisp.Text("Unsupported media type"),
    )
}

pub fn multipart_form_with_files_test() {
  let data =
    "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary\r
Content-Disposition: form-data; name=\"two\"; filename=\"file.txt\"\r
\r
file contents\r
--theboundary--\r
"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(fn(form) {
      let assert [#("one", "1")] = form.values
      let assert [#("two", wisp.UploadedFile("file.txt", path))] = form.files
      let assert Ok("file contents") = simplifile.read(path)
    })
    == wisp.ok()
}

pub fn multipart_form_files_too_big_test() {
  let testcase = fn(limit, callback) {
    let data =
      "--theboundary\r
Content-Disposition: form-data; name=\"two\"; filename=\"file.txt\"\r
\r
12\r
--theboundary\r
Content-Disposition: form-data; name=\"two\"\r
\r
this one isn't a file. If it was it would use the entire quota.\r
--theboundary\r
Content-Disposition: form-data; name=\"two\"; filename=\"another.txt\"\r
\r
34\r
--theboundary--\r
"
    simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> wisp.set_max_files_size(limit)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(callback)
  }

  assert testcase(1, fn(_) { panic as "should be unreachable for limit of 1" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )

  assert testcase(2, fn(_) { panic as "should be unreachable for limit of 2" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )

  assert testcase(3, fn(_) { panic as "should be unreachable for limit of 3" })
    == Response(
      413,
      [#("content-type", "text/plain")],
      wisp.Text("Content too large"),
    )

  assert testcase(4, fn(_) { Nil })
    == Response(200, [#("content-type", "text/plain")], wisp.Text("OK"))
}

pub fn handle_head_test() {
  let handler = fn(request, header) {
    use request <- wisp.handle_head(request)
    use <- wisp.require_method(request, http.Get)

    assert list.key_find(request.headers, "x-original-method") == header

    "Hello!"
    |> wisp.html_response(201)
  }

  assert simulate.request(http.Get, "/")
    |> request.set_method(http.Get)
    |> handler(Error(Nil))
    == Response(
      201,
      [#("content-type", "text/html; charset=utf-8")],
      wisp.Text("Hello!"),
    )

  assert simulate.request(http.Get, "/")
    |> request.set_method(http.Head)
    |> handler(Ok("HEAD"))
    == Response(
      201,
      [#("content-type", "text/html; charset=utf-8")],
      wisp.Text("Hello!"),
    )

  assert simulate.request(http.Get, "/")
    |> request.set_method(http.Post)
    |> handler(Error(Nil))
    == Response(405, [#("allow", "GET")], wisp.Text("Method not allowed"))
}

pub fn multipart_form_fields_are_sorted_test() {
  let data =
    "--theboundary\r
Content-Disposition: form-data; name=\"xx\"\r
\r
XX\r
--theboundary\r
Content-Disposition: form-data; name=\"zz\"\r
\r
ZZ\r
--theboundary\r
Content-Disposition: form-data; name=\"yy\"\r
\r
YY\r
--theboundary\r
Content-Disposition: form-data; name=\"cc\"; filename=\"file.txt\"\r
\r
CC\r
--theboundary\r
Content-Disposition: form-data; name=\"aa\"; filename=\"file.txt\"\r
\r
AA\r
--theboundary\r
Content-Disposition: form-data; name=\"bb\"; filename=\"file.txt\"\r
\r
BB\r
--theboundary--\r
"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(fn(form) {
      // Fields are sorted by name.
      let assert [#("xx", "XX"), #("yy", "YY"), #("zz", "ZZ")] = form.values
      let assert [
        #("aa", wisp.UploadedFile("file.txt", path_a)),
        #("bb", wisp.UploadedFile("file.txt", path_b)),
        #("cc", wisp.UploadedFile("file.txt", path_c)),
      ] = form.files
      let assert Ok("AA") = simplifile.read(path_a)
      let assert Ok("BB") = simplifile.read(path_b)
      let assert Ok("CC") = simplifile.read(path_c)
    })
    == wisp.ok()
}

pub fn urlencoded_form_fields_are_sorted_test() {
  let data = "xx=XX&zz=ZZ&yy=YY&cc=CC&aa=AA&bb=BB"
  assert simulate.request(http.Post, "/")
    |> simulate.string_body(data)
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> form_handler(fn(form) {
      // Fields are sorted by name.
      let assert [
        #("aa", "AA"),
        #("bb", "BB"),
        #("cc", "CC"),
        #("xx", "XX"),
        #("yy", "YY"),
        #("zz", "ZZ"),
      ] = form.values
    })
    == wisp.ok()
}

pub fn message_signing_test() {
  let request = simulate.request(http.Get, "/")
  let request1 = wisp.set_secret_key_base(request, wisp.random_string(64))
  let request2 = wisp.set_secret_key_base(request, wisp.random_string(64))

  let signed1 = wisp.sign_message(request1, <<"a":utf8>>, crypto.Sha512)
  let signed2 = wisp.sign_message(request2, <<"b":utf8>>, crypto.Sha512)

  let assert Ok(<<"a":utf8>>) = wisp.verify_signed_message(request1, signed1)
  let assert Ok(<<"b":utf8>>) = wisp.verify_signed_message(request2, signed2)

  let assert Error(Nil) = wisp.verify_signed_message(request1, signed2)
  let assert Error(Nil) = wisp.verify_signed_message(request2, signed1)
}

pub fn create_canned_connection_test() {
  let secret = wisp.random_string(64)
  let connection = wisp.create_canned_connection(<<"Hello!":utf8>>, secret)
  let request = request.set_body(request.new(), connection)

  assert wisp.get_secret_key_base(request) == secret

  assert wisp.read_body_bits(request) == Ok(<<"Hello!":utf8>>)
}

pub fn escape_html_test() {
  assert wisp.escape_html("<script>alert('&');</script>")
    == "&lt;script&gt;alert(&#39;&amp;&#39;);&lt;/script&gt;"
}

pub fn set_header_test() {
  assert wisp.ok()
    |> wisp.set_header("accept", "application/json")
    |> wisp.set_header("accept", "text/plain")
    |> wisp.set_header("content-type", "text/html")
    == Response(
      200,
      [#("content-type", "text/html"), #("accept", "text/plain")],
      wisp.Text("OK"),
    )
}

pub fn string_body_test() {
  assert wisp.string_body(wisp.ok(), "Hello, world!")
    == Response(
      200,
      [#("content-type", "text/plain")],
      wisp.Text("Hello, world!"),
    )
}

pub fn string_tree_body_test() {
  assert wisp.string_tree_body(
      wisp.ok(),
      string_tree.from_string("Hello, world!"),
    )
    == Response(
      200,
      [#("content-type", "text/plain")],
      wisp.Bytes(bytes_tree.from_string("Hello, world!")),
    )
}

pub fn json_body_test() {
  assert wisp.json_body(wisp.ok(), "{\"one\":1,\"two\":2}")
    == Response(
      200,
      [#("content-type", "application/json; charset=utf-8")],
      wisp.Text("{\"one\":1,\"two\":2}"),
    )
}

pub fn priv_directory_test() {
  let assert Error(Nil) = wisp.priv_directory("unknown_application")

  let assert Ok(dir) = wisp.priv_directory("wisp")
  let assert True = string.ends_with(dir, "/wisp/priv")

  let assert Ok(dir) = wisp.priv_directory("gleam_erlang")
  let assert True = string.ends_with(dir, "/gleam_erlang/priv")

  let assert Ok(dir) = wisp.priv_directory("gleam_stdlib")
  let assert True = string.ends_with(dir, "/gleam_stdlib/priv")
}

pub fn set_cookie_plain_test() {
  let req = simulate.request(http.Get, "/")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60 * 60 * 24 * 365)
    |> wisp.set_cookie(req, "flash", "hi-there", wisp.PlainText, 60)

  assert response.headers
    == [
      #(
        "set-cookie",
        "flash=aGktdGhlcmU; Max-Age=60; Path=/; Secure; HttpOnly; SameSite=Lax",
      ),
      #(
        "set-cookie",
        "id=MTIz; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax",
      ),
      #("content-type", "text/plain"),
    ]
}

pub fn set_cookie_signed_test() {
  let req = simulate.request(http.Get, "/")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.Signed, 60 * 60 * 24 * 365)
    |> wisp.set_cookie(req, "flash", "hi-there", wisp.Signed, 60)

  assert response.headers
    == [
      #(
        "set-cookie",
        "flash=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wA; Max-Age=60; Path=/; Secure; HttpOnly; SameSite=Lax",
      ),
      #(
        "set-cookie",
        "id=SFM1MTI.MTIz.LT5VxVwopQ7VhZ3OzF6Pgy3sfIIQaiUH5anHXNRt6o3taBMfCNBQskZ-EIkodchsPGSu_AJrAHjMfYPV7D5ogg; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax",
      ),
      #("content-type", "text/plain"),
    ]
}

/// If the scheme is HTTP and the `x-forwarded-proto` header is not set then
/// the `Secure` attribute is not set.
pub fn set_cookie_http_localhost_test() {
  let req = simulate.request(http.Get, "/")
  let req = request.Request(..req, scheme: http.Http, host: "localhost")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60)
  assert response.headers
    == [
      #("set-cookie", "id=MTIz; Max-Age=60; Path=/; HttpOnly; SameSite=Lax"),
      #("content-type", "text/plain"),
    ]
}

/// If the scheme is HTTP and the `x-forwarded-proto` header is not set then
/// the `Secure` attribute is not set.
pub fn set_cookie_http_localhost_ip4_test() {
  let req = simulate.request(http.Get, "/")
  let req = request.Request(..req, scheme: http.Http, host: "127.0.0.1")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60)
  assert response.headers
    == [
      #("set-cookie", "id=MTIz; Max-Age=60; Path=/; HttpOnly; SameSite=Lax"),
      #("content-type", "text/plain"),
    ]
}

/// If the scheme is HTTP and the `x-forwarded-proto` header is not set then
/// the `Secure` attribute is not set.
pub fn set_cookie_http_localhost_ip6_test() {
  let req = simulate.request(http.Get, "/")
  let req = request.Request(..req, scheme: http.Http, host: "[::1]")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60)
  assert response.headers
    == [
      #("set-cookie", "id=MTIz; Max-Age=60; Path=/; HttpOnly; SameSite=Lax"),
      #("content-type", "text/plain"),
    ]
}

/// If the scheme is HTTP but the `x-forwarded-proto` header is set then the
/// `Secure` attribute is set, regardless of what the header value is.
pub fn set_cookie_http_forwarded_test() {
  let req = simulate.request(http.Get, "/")
  let req =
    request.Request(..req, scheme: http.Http)
    |> request.set_header("x-forwarded-proto", "http")
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60)

  assert response.headers
    == [
      #(
        "set-cookie",
        "id=MTIz; Max-Age=60; Path=/; Secure; HttpOnly; SameSite=Lax",
      ),
      #("content-type", "text/plain"),
    ]
}

pub fn get_cookie_test() {
  let cookies =
    string.concat([
      // Plain text
      "plain=MTIz",
      ";",
      // Signed
      "signed=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wA",
      ";",
      // Signed but tampered with
      "signed-and-tampered-with=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wAA",
    ])
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", cookies)

  assert wisp.get_cookie(request, "plain", wisp.PlainText) == Ok("123")
  assert wisp.get_cookie(request, "plain", wisp.Signed) == Error(Nil)

  assert wisp.get_cookie(request, "signed", wisp.PlainText) == Error(Nil)
  assert wisp.get_cookie(request, "signed", wisp.Signed) == Ok("hi-there")

  assert wisp.get_cookie(request, "signed-and-tampered-with", wisp.PlainText)
    == Error(Nil)
  assert wisp.get_cookie(request, "signed-and-tampered-with", wisp.Signed)
    == Error(Nil)

  assert wisp.get_cookie(request, "unknown", wisp.PlainText) == Error(Nil)
  assert wisp.get_cookie(request, "unknown", wisp.Signed) == Error(Nil)
}

// Let's roundtrip signing and verification a bunch of times to have confidence
// it works, and that we detect any regressions.
pub fn cookie_sign_roundtrip_test() {
  use _ <- list.each(list.repeat(1, 10_000))
  let message =
    <<int.to_string(int.random(1_000_000_000_000_000)):utf8>>
    |> bit_array.base64_encode(True)
  let req = simulate.request(http.Get, "/")
  let signed = wisp.sign_message(req, <<message:utf8>>, crypto.Sha512)
  let req =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "message=" <> signed)
  let assert Ok(out) = wisp.get_cookie(req, "message", wisp.Signed)
  assert out == message
}

pub fn get_query_test() {
  assert simulate.request(http.Get, "/wibble?wobble=1&wubble=2&wobble=3&wabble")
    |> wisp.get_query
    == [
      #("wobble", "1"),
      #("wubble", "2"),
      #("wobble", "3"),
      #("wabble", ""),
    ]
}

pub fn get_query_no_query_test() {
  assert simulate.request(http.Get, "/wibble")
    |> wisp.get_query
    == []
}
