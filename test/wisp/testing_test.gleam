import gleam/http
import gleam/http/response
import gleam/option.{None}
import gleam/string_builder
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

pub fn string_body_empty_test() {
  wisp.ok()
  |> response.set_body(wisp.Empty)
  |> testing.string_body
  |> should.equal("")
}

pub fn string_body_file_test() {
  wisp.ok()
  |> response.set_body(wisp.File("test/fixture.txt"))
  |> testing.string_body
  |> should.equal("Hello, Joe!\n")
}

pub fn string_body_text_test() {
  wisp.ok()
  |> response.set_body(wisp.Text(string_builder.from_string("Hello, Joe!")))
  |> testing.string_body
  |> should.equal("Hello, Joe!")
}

pub fn bit_string_body_empty_test() {
  wisp.ok()
  |> response.set_body(wisp.Empty)
  |> testing.bit_string_body
  |> should.equal(<<>>)
}

pub fn bit_string_body_file_test() {
  wisp.ok()
  |> response.set_body(wisp.File("test/fixture.txt"))
  |> testing.bit_string_body
  |> should.equal(<<"Hello, Joe!\n":utf8>>)
}

pub fn bit_string_body_text_test() {
  wisp.ok()
  |> response.set_body(wisp.Text(string_builder.from_string("Hello, Joe!")))
  |> testing.bit_string_body
  |> should.equal(<<"Hello, Joe!":utf8>>)
}
