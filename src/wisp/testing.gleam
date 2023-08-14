import wisp.{Empty, File, Request, Response, Text}
import gleam/string_builder
import gleam/bit_builder
import gleam/uri
import gleam/http/request
import gleam/http
import gleam/option.{None}
import simplifile

/// The default secret key base used for test requests.
/// This should never be used outside of tests.
///
pub const default_secret_key_base: String = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

/// Create a test HTTP request that can be used to test your request handler
/// functions.
///
/// Note not all HTTP methods are expected to have an accompanying body, so when
/// using this function directly over other functions such as `get` and `post`
/// take care to ensure you are not providing a body when it is not expected.
/// 
/// The `default_secret_key_base` constant is used as the secret key base for
/// requests made with this function.
///
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

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn get(path: String, headers: List(http.Header)) -> Request {
  request(http.Get, path, headers, <<>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn post(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Post, path, headers, <<body:utf8>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
/// The body parameters are encoded as form data and the `content-type` header
/// is set to `application/x-www-form-urlencoded`.
/// 
pub fn post_form(
  path: String,
  headers: List(http.Header),
  data: List(#(String, String)),
) -> Request {
  let body = uri.query_to_string(data)
  request(http.Post, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn head(path: String, headers: List(http.Header)) -> Request {
  request(http.Head, path, headers, <<>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn put(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Put, path, headers, <<body:utf8>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
/// The body parameters are encoded as form data and the `content-type` header
/// is set to `application/x-www-form-urlencoded`.
/// 
pub fn put_form(
  path: String,
  headers: List(http.Header),
  data: List(#(String, String)),
) -> Request {
  let body = uri.query_to_string(data)
  request(http.Put, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn delete(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Delete, path, headers, <<body:utf8>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
/// The body parameters are encoded as form data and the `content-type` header
/// is set to `application/x-www-form-urlencoded`.
/// 
pub fn delete_form(
  path: String,
  headers: List(http.Header),
  data: List(#(String, String)),
) -> Request {
  let body = uri.query_to_string(data)
  request(http.Delete, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn trace(path: String, headers: List(http.Header)) -> Request {
  request(http.Trace, path, headers, <<>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn connect(path: String, headers: List(http.Header)) -> Request {
  request(http.Connect, path, headers, <<>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn options(path: String, headers: List(http.Header)) -> Request {
  request(http.Options, path, headers, <<>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
pub fn patch(path: String, headers: List(http.Header), body: String) -> Request {
  request(http.Patch, path, headers, <<body:utf8>>)
}

/// Create a test HTTP request that can be used to test your request handler.
/// 
/// The body parameters are encoded as form data and the `content-type` header is set to `application/x-www-form-urlencoded`.
/// 
pub fn patch_form(
  path: String,
  headers: List(http.Header),
  data: List(#(String, String)),
) -> Request {
  let body = uri.query_to_string(data)
  request(http.Patch, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
}

/// Read the body of a response as a string.
///
/// # Panics
///
/// This function will panic if the response body is a file and the file cannot
/// be read, or if it does not contain valid UTF-8.
///
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

/// Read the body of a response as a bit string
///
/// # Panics
///
/// This function will panic if the response body is a file and the file cannot
/// be read.
///
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
