import gleam/bit_array
import gleam/bytes_builder
import gleam/crypto
import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/string
import gleam/string_builder
import gleam/uri
import simplifile
import wisp.{type Request, type Response, Bytes, Empty, File, Text}

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
  body: BitArray,
) -> Request {
  let #(path, query) = case string.split(path, "?") {
    [path, query] -> #(path, Some(query))
    _ -> #(path, None)
  }
  request.Request(
    method: method,
    headers: headers,
    body: body,
    scheme: http.Https,
    host: "localhost",
    port: None,
    path: path,
    query: query,
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
/// The `content-type` header is set to `application/json`.
/// 
pub fn post_json(
  path: String,
  headers: List(http.Header),
  data: Json,
) -> Request {
  let body = json.to_string(data)
  request(http.Post, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/json")
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
/// The `content-type` header is set to `application/json`.
/// 
pub fn put_json(path: String, headers: List(http.Header), data: Json) -> Request {
  let body = json.to_string(data)
  request(http.Put, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/json")
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
/// The `content-type` header is set to `application/json`.
/// 
pub fn delete_json(
  path: String,
  headers: List(http.Header),
  data: Json,
) -> Request {
  let body = json.to_string(data)
  request(http.Delete, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/json")
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

/// Create a test HTTP request that can be used to test your request handler.
/// 
/// The `content-type` header is set to `application/json`.
/// 
pub fn patch_json(
  path: String,
  headers: List(http.Header),
  data: Json,
) -> Request {
  let body = json.to_string(data)
  request(http.Patch, path, headers, <<body:utf8>>)
  |> request.set_header("content-type", "application/json")
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
    Bytes(bytes) -> {
      let data = bytes_builder.to_bit_array(bytes)
      let assert Ok(string) = bit_array.to_string(data)
      string
    }
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
pub fn bit_array_body(response: Response) -> BitArray {
  case response.body {
    Empty -> <<>>
    Bytes(builder) -> bytes_builder.to_bit_array(builder)
    Text(builder) ->
      bytes_builder.to_bit_array(bytes_builder.from_string_builder(builder))
    File(path) -> {
      let assert Ok(contents) = simplifile.read_bits(path)
      contents
    }
  }
}

/// Set a header on a request.
/// 
/// # Examples
/// 
/// ```gleam
/// let request =
///   test.request(test.Get, "/", [], <<>>)
///   |> test.set_header("content-type", "application/json")
/// request.headers
/// // => [#("content-type", "application/json")]
/// ```
pub const set_header = request.set_header

/// Set a cookie on the request.
/// 
pub fn set_cookie(
  req: Request,
  name: String,
  value: String,
  security: wisp.Security,
) -> Request {
  let value = case security {
    wisp.PlainText -> bit_array.base64_encode(<<value:utf8>>, False)
    wisp.Signed -> wisp.sign_message(req, <<value:utf8>>, crypto.Sha512)
  }
  request.set_cookie(req, name, value)
}
