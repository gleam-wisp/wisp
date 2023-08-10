import wisp.{Empty, File, Request, Response, Text}
import gleam/string_builder
import gleam/bit_builder
import gleam/http/request
import gleam/http
import gleam/option.{None}
import simplifile

/// The default secret key base used for test requests.
/// This should never be used outside of tests.
///
pub const default_secret_key_base: String = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

// TODO: document
pub fn request(
  method: http.Method,
  path: String,
  headers: List(http.Header),
  body: BitString,
) -> Request {
  request.Request(
    method: method,
    headers: headers,
    body: body,
    scheme: http.Https,
    host: "localhost",
    port: None,
    path: path,
    query: None,
  )
  |> request.set_body(wisp.create_canned_connection(
    body,
    default_secret_key_base,
  ))
}

// TODO: document
pub fn get(path: String, headers: List(http.Header)) -> Request {
  request(http.Get, path, headers, <<>>)
}

// TODO: document
pub fn post(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Post, path, headers, <<body:utf8>>)
}

// TODO: document
pub fn head(path: String, headers: List(http.Header)) -> Request {
  request(http.Head, path, headers, <<>>)
}

// TODO: document
pub fn put(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Put, path, headers, <<body:utf8>>)
}

// TODO: document
pub fn delete(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Delete, path, headers, <<body:utf8>>)
}

// TODO: document
pub fn trace(path: String, headers: List(http.Header)) -> Request {
  request(http.Trace, path, headers, <<>>)
}

// TODO: document
pub fn connect(path: String, headers: List(http.Header)) -> Request {
  request(http.Connect, path, headers, <<>>)
}

// TODO: document
pub fn options(path: String, headers: List(http.Header)) -> Request {
  request(http.Options, path, headers, <<>>)
}

// TODO: document
pub fn patch(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Patch, path, headers, <<body:utf8>>)
}

// TODO: test
// TODO: document
pub fn string_body(response: Response) -> String {
  case response.body {
    Empty -> ""
    Text(builder) -> string_builder.to_string(builder)
    File(path) -> {
      let assert Ok(contents) = simplifile.read(path)
      contents
    }
  }
}

// TODO: test
// TODO: document
pub fn bit_string_body(response: Response) -> BitString {
  case response.body {
    Empty -> <<>>
    Text(builder) ->
      bit_builder.to_bit_string(bit_builder.from_string_builder(builder))
    File(path) -> {
      let assert Ok(contents) = simplifile.read_bits(path)
      contents
    }
  }
}
