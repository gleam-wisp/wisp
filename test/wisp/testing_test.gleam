import gleam/http
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleam/string_tree
import gleeunit/should
import wisp
import wisp/testing

pub fn request_test() {
  let request =
    testing.request(
      http.Patch,
      "/wibble/woo",
      [#("content-type", "application/json")],
      <<"wubwub":utf8>>,
    )

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn get_test() {
  let request =
    testing.get("/wibble/woo", [#("content-type", "application/json")])

  request.method
  |> should.equal(http.Get)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<>>))
}

pub fn head_test() {
  let request =
    testing.head("/wibble/woo", [#("content-type", "application/json")])

  request.method
  |> should.equal(http.Head)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<>>))
}

pub fn post_test() {
  let request =
    testing.post(
      "/wibble/woo",
      [#("content-type", "application/json")],
      "wubwub",
    )

  request.method
  |> should.equal(http.Post)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn post_form_test() {
  let request =
    testing.post_form(
      "/wibble/woo",
      [#("content-type", "application/json"), #("accept", "application/json")],
      [#("one", "two"), #("three", "four!?")],
    )

  request.method
  |> should.equal(http.Post)
  request.headers
  |> should.equal([
    #("content-type", "application/x-www-form-urlencoded"),
    #("accept", "application/json"),
  ])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"one=two&three=four!%3F":utf8>>))
}

pub fn post_json_test() {
  let json =
    json.object([
      #("one", json.string("two")),
      #("three", json.string("four!?")),
    ])
  let request = testing.post_json("/wibble/woo", [], json)

  request.method
  |> should.equal(http.Post)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn patch_test() {
  let request =
    testing.patch(
      "/wibble/woo",
      [#("content-type", "application/json")],
      "wubwub",
    )

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn patch_form_test() {
  let request =
    testing.patch_form(
      "/wibble/woo",
      [#("content-type", "application/json"), #("accept", "application/json")],
      [#("one", "two"), #("three", "four!?")],
    )

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([
    #("content-type", "application/x-www-form-urlencoded"),
    #("accept", "application/json"),
  ])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"one=two&three=four!%3F":utf8>>))
}

pub fn patch_json_test() {
  let json =
    json.object([
      #("one", json.string("two")),
      #("three", json.string("four!?")),
    ])
  let request = testing.patch_json("/wibble/woo", [], json)

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn options_test() {
  let request =
    testing.options("/wibble/woo", [#("content-type", "application/json")])

  request.method
  |> should.equal(http.Options)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<>>))
}

pub fn connect_test() {
  let request =
    testing.connect("/wibble/woo", [#("content-type", "application/json")])

  request.method
  |> should.equal(http.Connect)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<>>))
}

pub fn trace_test() {
  let request =
    testing.trace("/wibble/woo", [#("content-type", "application/json")])

  request.method
  |> should.equal(http.Trace)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<>>))
}

pub fn delete_test() {
  let request =
    testing.delete(
      "/wibble/woo",
      [#("content-type", "application/json")],
      "wubwub",
    )

  request.method
  |> should.equal(http.Delete)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn delete_form_test() {
  let request =
    testing.delete_form(
      "/wibble/woo",
      [#("content-type", "application/json"), #("accept", "application/json")],
      [#("one", "two"), #("three", "four!?")],
    )

  request.method
  |> should.equal(http.Delete)
  request.headers
  |> should.equal([
    #("content-type", "application/x-www-form-urlencoded"),
    #("accept", "application/json"),
  ])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"one=two&three=four!%3F":utf8>>))
}

pub fn delete_json_test() {
  let json =
    json.object([
      #("one", json.string("two")),
      #("three", json.string("four!?!")),
    ])
  let request = testing.delete_json("/wibble/woo", [], json)

  request.method
  |> should.equal(http.Delete)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn put_test() {
  let request =
    testing.put(
      "/wibble/woo",
      [#("content-type", "application/json")],
      "wubwub",
    )

  request.method
  |> should.equal(http.Put)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn put_form_test() {
  let request =
    testing.put_form(
      "/wibble/woo",
      [#("content-type", "application/json"), #("accept", "application/json")],
      [#("one", "two"), #("three", "four!?")],
    )

  request.method
  |> should.equal(http.Put)
  request.headers
  |> should.equal([
    #("content-type", "application/x-www-form-urlencoded"),
    #("accept", "application/json"),
  ])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"one=two&three=four!%3F":utf8>>))
}

pub fn put_json_test() {
  let json =
    json.object([
      #("one", json.string("two")),
      #("three", json.string("four!?!")),
    ])
  let request = testing.put_json("/wibble/woo", [], json)

  request.method
  |> should.equal(http.Put)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(None)
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn string_body_empty_test() {
  wisp.ok()
  |> response.set_body(wisp.Empty)
  |> testing.string_body
  |> should.equal("")
}

pub fn string_body_file_test() {
  wisp.ok()
  |> response.set_body(wisp.File("test/fixture.txt", 0, option.None))
  |> testing.string_body
  |> should.equal("Hello, Joe!\n")
}

pub fn string_body_text_test() {
  wisp.ok()
  |> response.set_body(wisp.Text(string_tree.from_string("Hello, Joe!")))
  |> testing.string_body
  |> should.equal("Hello, Joe!")
}

pub fn bit_array_body_empty_test() {
  wisp.ok()
  |> response.set_body(wisp.Empty)
  |> testing.bit_array_body
  |> should.equal(<<>>)
}

pub fn bit_array_body_file_test() {
  wisp.ok()
  |> response.set_body(wisp.File("test/fixture.txt", 0, option.None))
  |> testing.bit_array_body
  |> should.equal(<<"Hello, Joe!\n":utf8>>)
}

pub fn bit_array_body_text_test() {
  wisp.ok()
  |> response.set_body(wisp.Text(string_tree.from_string("Hello, Joe!")))
  |> testing.bit_array_body
  |> should.equal(<<"Hello, Joe!":utf8>>)
}

pub fn request_query_string_test() {
  let request =
    testing.request(
      http.Patch,
      "/wibble/woo?one=two&three=four",
      [#("content-type", "application/json")],
      <<"wubwub":utf8>>,
    )

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.scheme
  |> should.equal(http.Https)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/wibble/woo")
  request.query
  |> should.equal(Some("one=two&three=four"))
  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<"wubwub":utf8>>))
}

pub fn set_header_test() {
  let request = testing.get("/", [])

  request.headers
  |> should.equal([])

  // Set new headers
  let request =
    request
    |> testing.set_header("content-type", "application/json")
    |> testing.set_header("accept", "application/json")
  request.headers
  |> should.equal([
    #("content-type", "application/json"),
    #("accept", "application/json"),
  ])

  // Replace the header
  let request = testing.set_header(request, "content-type", "text/plain")
  request.headers
  |> should.equal([
    #("content-type", "text/plain"),
    #("accept", "application/json"),
  ])
}

pub fn set_cookie_plain_text_test() {
  let req =
    testing.get("/", [])
    |> testing.set_cookie("abc", "1234", wisp.PlainText)
    |> testing.set_cookie("def", "5678", wisp.PlainText)
  req.headers
  |> should.equal([#("cookie", "abc=MTIzNA; def=NTY3OA")])
}

pub fn set_cookie_signed_test() {
  let req =
    testing.get("/", [])
    |> testing.set_cookie("abc", "1234", wisp.Signed)
    |> testing.set_cookie("def", "5678", wisp.Signed)
  req.headers
  |> should.equal([
    #(
      "cookie",
      "abc=SFM1MTI.MTIzNA.QWGuB_lZLssnh71rC6R5_WOr8MDr8dxE3C_2JvLRAAC4ad4SnmQk0Fl_6_RrtmzdH2O3WaNPExkJsuwBixtWIA; def=SFM1MTI.NTY3OA.R3HRe5woa1qwxvjRUC5ggQVd3hTqGCXIk_4ybU35SXPtGvLrFpHBXWGIjyG5QeuEk9j3jnWIL3ct18olJiSCMw",
    ),
  ])
}
