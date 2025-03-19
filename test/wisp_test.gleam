import exception
import gleam/bit_array
import gleam/crypto
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/int
import gleam/list
import gleam/set
import gleam/string
import gleam/string_tree
import gleeunit
import gleeunit/should
import simplifile
import wisp
import wisp/internal
import wisp/testing

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

pub fn redirect_test() {
  wisp.redirect(to: "https://example.com/wibble")
  |> should.equal(Response(
    303,
    [#("location", "https://example.com/wibble")],
    wisp.Empty,
  ))
}

pub fn moved_permanently_test() {
  wisp.moved_permanently(to: "https://example.com/wobble")
  |> should.equal(Response(
    308,
    [#("location", "https://example.com/wobble")],
    wisp.Empty,
  ))
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

pub fn unsupported_media_type_test() {
  wisp.unsupported_media_type(accept: ["application/json", "text/plain"])
  |> should.equal(Response(
    415,
    [#("accept", "application/json, text/plain")],
    wisp.Empty,
  ))
}

pub fn unprocessable_entity_test() {
  wisp.unprocessable_entity()
  |> should.equal(Response(422, [], wisp.Empty))
}

pub fn json_response_test() {
  let body = string_tree.from_string("{\"one\":1,\"two\":2}")
  let response = wisp.json_response(body, 201)
  response.status
  |> should.equal(201)
  response.headers
  |> should.equal([#("content-type", "application/json; charset=utf-8")])
  response
  |> testing.string_body
  |> should.equal("{\"one\":1,\"two\":2}")
}

pub fn html_response_test() {
  let body = string_tree.from_string("Hello, world!")
  let response = wisp.html_response(body, 200)
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])
  response
  |> testing.string_body
  |> should.equal("Hello, world!")
}

pub fn html_body_test() {
  let body = string_tree.from_string("Hello, world!")
  let response =
    wisp.method_not_allowed([http.Get])
    |> wisp.html_body(body)
  response.status
  |> should.equal(405)
  response.headers
  |> should.equal([
    #("allow", "GET"),
    #("content-type", "text/html; charset=utf-8"),
  ])
  response
  |> testing.string_body
  |> should.equal("Hello, world!")
}

pub fn random_string_test() {
  let count = 10_000
  let new = fn(_) {
    let random = wisp.random_string(64)
    string.length(random)
    |> should.equal(64)
    random
  }

  list.repeat(Nil, count)
  |> list.map(new)
  |> set.from_list
  |> set.size
  |> should.equal(count)
}

pub fn set_get_secret_key_base_test() {
  let request = testing.get("/", [])
  let valid = wisp.random_string(64)
  let too_short = wisp.random_string(63)

  request
  |> wisp.get_secret_key_base
  |> should.equal(testing.default_secret_key_base)

  request
  |> wisp.set_secret_key_base(valid)
  |> wisp.get_secret_key_base
  |> should.equal(valid)

  // Panics if the key is too short
  erlang.rescue(fn() { wisp.set_secret_key_base(request, too_short) })
  |> should.be_error
}

pub fn set_get_max_body_size_test() {
  let request = testing.get("/", [])

  request
  |> wisp.get_max_body_size
  |> should.equal(8_000_000)

  request
  |> wisp.set_max_body_size(10)
  |> wisp.get_max_body_size
  |> should.equal(10)
}

pub fn set_get_max_files_size_test() {
  let request = testing.get("/", [])

  request
  |> wisp.get_max_files_size
  |> should.equal(32_000_000)

  request
  |> wisp.set_max_files_size(10)
  |> wisp.get_max_files_size
  |> should.equal(10)
}

pub fn set_get_read_chunk_size_test() {
  let request = testing.get("/", [])

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

pub fn require_string_body_test() {
  {
    let request = testing.post("/", [], "Hello, Joe!")
    use body <- wisp.require_string_body(request)
    body
    |> should.equal("Hello, Joe!")
    wisp.accepted()
  }
  |> should.equal(wisp.accepted())
}

pub fn require_string_body_invalid_test() {
  {
    let request = testing.request(http.Post, "/", [], <<254>>)
    use _ <- wisp.require_string_body(request)
    panic as "should be unreachable"
  }
  |> should.equal(wisp.bad_request())
}

pub fn rescue_crashes_error_test() {
  wisp.set_logger_level(wisp.CriticalLevel)
  use <- exception.defer(fn() { wisp.set_logger_level(wisp.InfoLevel) })

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
  let handler = fn(request) {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }

  // Get a text file
  let response =
    testing.get("/stuff/test/fixture.txt", [])
    |> handler
  let assert Ok(etag) = internal.generate_etag("test/fixture.txt")

  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([
    #("content-type", "text/plain; charset=utf-8"),
    #("etag", etag),
  ])
  response.body
  |> should.equal(wisp.File("./test/fixture.txt"))

  // Get a json file
  let response =
    testing.get("/stuff/test/fixture.json", [])
    |> handler
  let assert Ok(etag) = internal.generate_etag("test/fixture.json")

  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([
    #("content-type", "application/json; charset=utf-8"),
    #("etag", etag),
  ])
  response.body
  |> should.equal(wisp.File("./test/fixture.json"))

  // Get some other file
  let response =
    testing.get("/stuff/test/fixture.dat", [])
    |> handler
  let assert Ok(etag) = internal.generate_etag("test/fixture.dat")

  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([
    #("content-type", "application/octet-stream"),
    #("etag", etag),
  ])
  response.body
  |> should.equal(wisp.File("./test/fixture.dat"))

  // Get something not handled by the static file server
  let response =
    testing.get("/stuff/this-does-not-exist", [])
    |> handler
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([])
  response.body
  |> should.equal(wisp.Empty)
}

pub fn serve_static_under_has_no_trailing_slash_test() {
  let request =
    testing.get("/", [])
    |> request.set_path("/stuff/test/fixture.txt")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: "./")
    wisp.ok()
  }
  let assert Ok(etag) = internal.generate_etag("test/fixture.txt")

  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([
    #("content-type", "text/plain; charset=utf-8"),
    #("etag", etag),
  ])
  response.body
  |> should.equal(wisp.File("./test/fixture.txt"))
}

pub fn serve_static_from_has_no_trailing_slash_test() {
  let request =
    testing.get("/", [])
    |> request.set_path("/stuff/test/fixture.txt")
  let response = {
    use <- wisp.serve_static(request, under: "stuff", from: ".")
    wisp.ok()
  }
  let assert Ok(etag) = internal.generate_etag("test/fixture.txt")

  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([
    #("content-type", "text/plain; charset=utf-8"),
    #("etag", etag),
  ])
  response.body
  |> should.equal(wisp.File("./test/fixture.txt"))
}

pub fn serve_static_not_found_test() {
  let request =
    testing.get("/", [])
    |> request.set_path("/stuff/credit_card_details.txt")
  {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn serve_static_go_up_test() {
  let request =
    testing.get("/", [])
    |> request.set_path("/../test/fixture.txt")
  {
    use <- wisp.serve_static(request, under: "/stuff", from: "./src/")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn serve_static_etags_returns_304_test() {
  let handler = fn(request) {
    use <- wisp.serve_static(request, under: "/stuff", from: "./")
    wisp.ok()
  }

  // Get a text file without any headers
  let response =
    testing.get("/stuff/test/fixture.txt", [])
    |> handler
  let assert Ok(etag) = internal.generate_etag("test/fixture.txt")

  should.equal(response.status, 200)
  should.equal(response.headers, [
    #("content-type", "text/plain; charset=utf-8"),
    #("etag", etag),
  ])
  should.equal(response.body, wisp.File("./test/fixture.txt"))

  // Get a text file with outdated if-none-match header
  let response =
    testing.get("/stuff/test/fixture.txt", [#("if-none-match", "invalid-etag")])
    |> handler

  should.equal(response.status, 200)
  should.equal(response.headers, [
    #("content-type", "text/plain; charset=utf-8"),
    #("etag", etag),
  ])
  should.equal(response.body, wisp.File("./test/fixture.txt"))

  // Get a text file with current etag in if-none-match header
  let response =
    testing.get("/stuff/test/fixture.txt", [#("if-none-match", etag)])
    |> handler

  should.equal(response.status, 304)
  should.equal(response.headers, [])
  should.equal(response.body, wisp.Empty)
}

pub fn temporary_file_test() {
  // Create tmp files for a first request
  let request1 = testing.get("/", [])
  let assert Ok(request1_file1) = wisp.new_temporary_file(request1)
  let assert Ok(request1_file2) = wisp.new_temporary_file(request1)

  // The files exist
  request1_file1
  |> should.not_equal(request1_file2)
  let assert Ok(_) = simplifile.read(request1_file1)
  let assert Ok(_) = simplifile.read(request1_file2)

  // Create tmp files for a second request
  let request2 = testing.get("/", [])
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

pub fn require_content_type_test() {
  {
    let request = testing.get("/", [#("content-type", "text/plain")])
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn require_content_type_charset_test() {
  {
    let request =
      testing.get("/", [#("content-type", "text/plain; charset=utf-8")])
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  |> should.equal(wisp.ok())
}

pub fn require_content_type_missing_test() {
  {
    let request = testing.get("/", [])
    use <- wisp.require_content_type(request, "text/plain")
    wisp.ok()
  }
  |> should.equal(wisp.unsupported_media_type(["text/plain"]))
}

pub fn require_content_type_invalid_test() {
  {
    let request = testing.get("/", [#("content-type", "text/plain")])
    use <- wisp.require_content_type(request, "text/html")
    panic as "should be unreachable"
  }
  |> should.equal(wisp.unsupported_media_type(["text/html"]))
}

pub fn json_test() {
  testing.post("/", [], "{\"one\":1,\"two\":2}")
  |> request.set_header("content-type", "application/json")
  |> json_handler(fn(json) {
    json
    |> should.equal(dynamic.from(dict.from_list([#("one", 1), #("two", 2)])))
  })
  |> should.equal(wisp.ok())
}

pub fn json_wrong_content_type_test() {
  testing.post("/", [], "{\"one\":1,\"two\":2}")
  |> request.set_header("content-type", "text/plain")
  |> json_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(wisp.unsupported_media_type(["application/json"]))
}

pub fn json_no_content_type_test() {
  testing.post("/", [], "{\"one\":1,\"two\":2}")
  |> json_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(wisp.unsupported_media_type(["application/json"]))
}

pub fn json_too_big_test() {
  testing.post("/", [], "{\"one\":1,\"two\":2}")
  |> wisp.set_max_body_size(1)
  |> request.set_header("content-type", "application/json")
  |> json_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(413, [], wisp.Empty))
}

pub fn json_syntax_error_test() {
  testing.post("/", [], "{\"one\":1,\"two\":2")
  |> request.set_header("content-type", "application/json")
  |> json_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(400, [], wisp.Empty))
}

pub fn urlencoded_form_test() {
  testing.post("/", [], "one=1&two=2")
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
  |> form_handler(fn(form) {
    form
    |> should.equal(wisp.FormData([#("one", "1"), #("two", "2")], []))
  })
  |> should.equal(wisp.ok())
}

pub fn urlencoded_form_with_charset_test() {
  testing.post("/", [], "one=1&two=2")
  |> request.set_header(
    "content-type",
    "application/x-www-form-urlencoded; charset=UTF-8",
  )
  |> form_handler(fn(form) {
    form
    |> should.equal(wisp.FormData([#("one", "1"), #("two", "2")], []))
  })
  |> should.equal(wisp.ok())
}

pub fn urlencoded_too_big_form_test() {
  testing.post("/", [], "12")
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
  |> wisp.set_max_body_size(1)
  |> form_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(413, [], wisp.Empty))
}

pub fn multipart_form_test() {
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
  |> testing.post("/", [], _)
  |> request.set_header(
    "content-type",
    "multipart/form-data; boundary=theboundary",
  )
  |> form_handler(fn(form) {
    form
    |> should.equal(wisp.FormData([#("one", "1"), #("two", "2")], []))
  })
  |> should.equal(wisp.ok())
}

pub fn multipart_form_too_big_test() {
  "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary--\r
"
  |> testing.post("/", [], _)
  |> wisp.set_max_body_size(1)
  |> request.set_header(
    "content-type",
    "multipart/form-data; boundary=theboundary",
  )
  |> form_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(413, [], wisp.Empty))
}

pub fn multipart_form_no_boundary_test() {
  "--theboundary\r
Content-Disposition: form-data; name=\"one\"\r
\r
1\r
--theboundary--\r
"
  |> testing.post("/", [], _)
  |> request.set_header("content-type", "multipart/form-data")
  |> form_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(400, [], wisp.Empty))
}

pub fn multipart_form_invalid_format_test() {
  "--theboundary\r\n--theboundary--\r\n"
  |> testing.post("/", [], _)
  |> request.set_header(
    "content-type",
    "multipart/form-data; boundary=theboundary",
  )
  |> form_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(400, [], wisp.Empty))
}

pub fn form_unknown_content_type_test() {
  "one=1&two=2"
  |> testing.post("/", [], _)
  |> request.set_header("content-type", "text/form")
  |> form_handler(fn(_) { panic as "should be unreachable" })
  |> should.equal(Response(
    415,
    [#("accept", "application/x-www-form-urlencoded, multipart/form-data")],
    wisp.Empty,
  ))
}

pub fn multipart_form_with_files_test() {
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
  |> testing.post("/", [], _)
  |> request.set_header(
    "content-type",
    "multipart/form-data; boundary=theboundary",
  )
  |> form_handler(fn(form) {
    let assert [#("one", "1")] = form.values
    let assert [#("two", wisp.UploadedFile("file.txt", path))] = form.files
    let assert Ok("file contents") = simplifile.read(path)
  })
  |> should.equal(wisp.ok())
}

pub fn multipart_form_files_too_big_test() {
  let testcase = fn(limit, callback) {
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
    |> testing.post("/", [], _)
    |> wisp.set_max_files_size(limit)
    |> request.set_header(
      "content-type",
      "multipart/form-data; boundary=theboundary",
    )
    |> form_handler(callback)
  }

  testcase(1, fn(_) { panic as "should be unreachable for limit of 1" })
  |> should.equal(Response(413, [], wisp.Empty))

  testcase(2, fn(_) { panic as "should be unreachable for limit of 2" })
  |> should.equal(Response(413, [], wisp.Empty))

  testcase(3, fn(_) { panic as "should be unreachable for limit of 3" })
  |> should.equal(Response(413, [], wisp.Empty))

  testcase(4, fn(_) { Nil })
  |> should.equal(Response(200, [], wisp.Empty))
}

pub fn handle_head_test() {
  let handler = fn(request, header) {
    use request <- wisp.handle_head(request)
    use <- wisp.require_method(request, http.Get)

    list.key_find(request.headers, "x-original-method")
    |> should.equal(header)

    string_tree.from_string("Hello!")
    |> wisp.html_response(201)
  }

  testing.get("/", [])
  |> request.set_method(http.Get)
  |> handler(Error(Nil))
  |> should.equal(Response(
    201,
    [#("content-type", "text/html; charset=utf-8")],
    wisp.Text(string_tree.from_string("Hello!")),
  ))

  testing.get("/", [])
  |> request.set_method(http.Head)
  |> handler(Ok("HEAD"))
  |> should.equal(Response(
    201,
    [#("content-type", "text/html; charset=utf-8")],
    wisp.Text(string_tree.from_string("Hello!")),
  ))

  testing.get("/", [])
  |> request.set_method(http.Post)
  |> handler(Error(Nil))
  |> should.equal(Response(405, [#("allow", "GET")], wisp.Empty))
}

pub fn multipart_form_fields_are_sorted_test() {
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
  |> testing.post("/", [], _)
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
  |> should.equal(wisp.ok())
}

pub fn urlencoded_form_fields_are_sorted_test() {
  "xx=XX&zz=ZZ&yy=YY&cc=CC&aa=AA&bb=BB"
  |> testing.post("/", [], _)
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
  |> should.equal(wisp.ok())
}

pub fn message_signing_test() {
  let request = testing.get("/", [])
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

  request
  |> wisp.get_secret_key_base
  |> should.equal(secret)

  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"Hello!":utf8>>))
}

pub fn escape_html_test() {
  "<script>alert('&');</script>"
  |> wisp.escape_html
  |> should.equal("&lt;script&gt;alert('&amp;');&lt;/script&gt;")
}

pub fn set_header_test() {
  wisp.ok()
  |> wisp.set_header("accept", "application/json")
  |> wisp.set_header("accept", "text/plain")
  |> wisp.set_header("content-type", "text/html")
  |> should.equal(Response(
    200,
    [#("accept", "text/plain"), #("content-type", "text/html")],
    wisp.Empty,
  ))
}

pub fn string_body_test() {
  wisp.ok()
  |> wisp.string_body("Hello, world!")
  |> should.equal(Response(
    200,
    [],
    wisp.Text(string_tree.from_string("Hello, world!")),
  ))
}

pub fn string_tree_body_test() {
  wisp.ok()
  |> wisp.string_tree_body(string_tree.from_string("Hello, world!"))
  |> should.equal(Response(
    200,
    [],
    wisp.Text(string_tree.from_string("Hello, world!")),
  ))
}

pub fn json_body_test() {
  wisp.ok()
  |> wisp.json_body(string_tree.from_string("{\"one\":1,\"two\":2}"))
  |> should.equal(Response(
    200,
    [#("content-type", "application/json; charset=utf-8")],
    wisp.Text(string_tree.from_string("{\"one\":1,\"two\":2}")),
  ))
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
  let req = testing.get("/", [])
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.PlainText, 60 * 60 * 24 * 365)
    |> wisp.set_cookie(req, "flash", "hi-there", wisp.PlainText, 60)

  response.headers
  |> should.equal([
    #(
      "set-cookie",
      "flash=aGktdGhlcmU; Max-Age=60; Path=/; Secure; HttpOnly; SameSite=Lax",
    ),
    #(
      "set-cookie",
      "id=MTIz; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax",
    ),
  ])
}

pub fn set_cookie_signed_test() {
  let req = testing.get("/", [])
  let response =
    wisp.ok()
    |> wisp.set_cookie(req, "id", "123", wisp.Signed, 60 * 60 * 24 * 365)
    |> wisp.set_cookie(req, "flash", "hi-there", wisp.Signed, 60)

  response.headers
  |> should.equal([
    #(
      "set-cookie",
      "flash=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wA; Max-Age=60; Path=/; Secure; HttpOnly; SameSite=Lax",
    ),
    #(
      "set-cookie",
      "id=SFM1MTI.MTIz.LT5VxVwopQ7VhZ3OzF6Pgy3sfIIQaiUH5anHXNRt6o3taBMfCNBQskZ-EIkodchsPGSu_AJrAHjMfYPV7D5ogg; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax",
    ),
  ])
}

pub fn get_cookie_test() {
  let request =
    testing.get("/", [
      // Plain text
      #("cookie", "plain=MTIz"),
      // Signed
      #(
        "cookie",
        "signed=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wA",
      ),
      // Signed but tampered with
      #(
        "cookie",
        "signed-and-tampered-with=SFM1MTI.aGktdGhlcmU.uWUWvrAleKQ2jsWcU97HzGgPqtLjjUgl4oe40-RPJ5qRRcE_soXPacgmaHTLxK3xZbOJ5DOTIRMI0szD4Re7wAA",
      ),
    ])

  request
  |> wisp.get_cookie("plain", wisp.PlainText)
  |> should.equal(Ok("123"))
  request
  |> wisp.get_cookie("plain", wisp.Signed)
  |> should.equal(Error(Nil))

  request
  |> wisp.get_cookie("signed", wisp.PlainText)
  |> should.equal(Error(Nil))
  request
  |> wisp.get_cookie("signed", wisp.Signed)
  |> should.equal(Ok("hi-there"))

  request
  |> wisp.get_cookie("signed-and-tampered-with", wisp.PlainText)
  |> should.equal(Error(Nil))
  request
  |> wisp.get_cookie("signed-and-tampered-with", wisp.Signed)
  |> should.equal(Error(Nil))

  request
  |> wisp.get_cookie("unknown", wisp.PlainText)
  |> should.equal(Error(Nil))
  request
  |> wisp.get_cookie("unknown", wisp.Signed)
  |> should.equal(Error(Nil))
}

// Let's roundtrip signing and verification a bunch of times to have confidence
// it works, and that we detect any regressions.
pub fn cookie_sign_roundtrip_test() {
  use _ <- list.each(list.repeat(1, 10_000))
  let message =
    <<int.to_string(int.random(1_000_000_000_000_000)):utf8>>
    |> bit_array.base64_encode(True)
  let req = testing.get("/", [])
  let signed = wisp.sign_message(req, <<message:utf8>>, crypto.Sha512)
  let req = testing.get("/", [#("cookie", "message=" <> signed)])
  let assert Ok(out) = wisp.get_cookie(req, "message", wisp.Signed)
  out
  |> should.equal(message)
}

pub fn get_query_test() {
  testing.get("/wibble?wobble=1&wubble=2&wobble=3&wabble", [])
  |> wisp.get_query
  |> should.equal([
    #("wobble", "1"),
    #("wubble", "2"),
    #("wobble", "3"),
    #("wabble", ""),
  ])
}

pub fn get_query_no_query_test() {
  testing.get("/wibble", [])
  |> wisp.get_query
  |> should.equal([])
}
