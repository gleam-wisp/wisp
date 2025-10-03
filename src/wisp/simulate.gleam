import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/uri
import gleam/yielder
import simplifile
import wisp.{type Request, type Response, Bytes, Chunks, File, Text}

/// Create a test request that can be used to test your request handler
/// functions.
///
/// If you are testing handlers that are intended to be accessed from a browser
/// (such as those that use cookies) consider using `browser_request` instead.
///
pub fn request(method: http.Method, path: String) -> Request {
  let #(path, query) = case string.split_once(path, "?") {
    Ok(#(path, query)) -> #(path, Some(query))
    _ -> #(path, None)
  }
  let connection = wisp.create_canned_connection(<<>>, default_secret_key_base)
  request.Request(
    method: method,
    headers: default_headers,
    body: connection,
    scheme: http.Https,
    host: default_host,
    port: None,
    path: path,
    query: query,
  )
}

/// Create a test request with browser-set headers that can be used to test
/// your request handler functions.
///
/// The `origin` header is set when using this function.
///
pub fn browser_request(method: http.Method, path: String) -> Request {
  request.Request(..request(method, path), headers: default_browser_headers)
}

/// Continue a browser session from a previous request and response, adopting
/// the request cookies, and updating the cookies as specified by the response.
///
pub fn session(
  next_request: Request,
  previous_request: Request,
  previous_response: Response,
) -> Request {
  let request = case list.key_find(previous_request.headers, "cookie") {
    Ok(cookies) -> header(next_request, "cookie", cookies)
    Error(_) -> next_request
  }

  let set_cookies =
    // Get the newly set cookies
    list.key_filter(previous_response.headers, "set-cookie")
    // Parse them to get the name, value, and attributes
    |> list.map(fn(cookie) {
      case string.split_once(cookie, ";") {
        Ok(#(cookie, attributes)) -> {
          let attributes =
            string.split(attributes, ";") |> list.map(string.trim)
          #(cookie, attributes)
        }
        Error(Nil) -> #(cookie, [])
      }
    })
    |> list.filter_map(fn(cookie) {
      string.split_once(cookie.0, "=")
      |> result.map(fn(split) { #(split.0, split.1, cookie.1) })
    })

  // Set or remove the cookies as needed on the request
  list.fold(set_cookies, request, fn(request, cookie) {
    case list.contains(cookie.2, "Max-Age=0") {
      True -> request.remove_cookie(request, cookie.0)
      False -> request.set_cookie(request, cookie.0, cookie.1)
    }
  })
}

/// Add a text body to the request.
/// 
/// The `content-type` header is set to `text/plain`. You may want to override
/// this with `request.set_header`.
/// 
pub fn string_body(request: Request, text: String) -> Request {
  let body =
    text
    |> bit_array.from_string
    |> wisp.create_canned_connection(default_secret_key_base)
  request
  |> request.set_body(body)
  |> request.set_header("content-type", "text/plain")
}

/// Add a binary body to the request.
/// 
/// The `content-type` header is set to `application/octet-stream`. You may
/// want to override/ this with `request.set_header`.
/// 
pub fn bit_array_body(request: Request, data: BitArray) -> Request {
  let body = wisp.create_canned_connection(data, default_secret_key_base)
  request
  |> request.set_body(body)
  |> request.set_header("content-type", "application/octet-stream")
}

/// Add HTML body to the request.
/// 
/// The `content-type` header is set to `text/html; charset=utf-8`.
/// 
pub fn html_body(request: Request, html: String) -> Request {
  let body =
    html
    |> bit_array.from_string
    |> wisp.create_canned_connection(default_secret_key_base)
  request
  |> request.set_body(body)
  |> request.set_header("content-type", "text/html; charset=utf-8")
}

/// Add a form data body to the request.
/// 
/// The `content-type` header is set to `application/x-www-form-urlencoded`.
/// 
pub fn form_body(request: Request, data: List(#(String, String))) -> Request {
  let body =
    uri.query_to_string(data)
    |> bit_array.from_string
    |> wisp.create_canned_connection(default_secret_key_base)
  request
  |> request.set_body(body)
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
}

/// Add a JSON body to the request.
/// 
/// The `content-type` header is set to `application/json`.
/// 
pub fn json_body(request: Request, data: Json) -> Request {
  let body =
    json.to_string(data)
    |> bit_array.from_string
    |> wisp.create_canned_connection(default_secret_key_base)
  request
  |> request.set_body(body)
  |> request.set_header("content-type", "application/json")
}

/// Represents a file to be uploaded in a multipart form.
///
pub type FileUpload {
  FileUpload(file_name: String, content_type: String, content: BitArray)
}

/// Add a multipart/form-data body to the request for testing file uploads
/// and form submissions.
/// 
/// The `content-type` header is set to `multipart/form-data` with an
/// appropriate boundary.
/// 
/// # Examples
/// 
/// ```gleam
/// let file = UploadedFile(
///   file_name: "test.txt", 
///   content_type: "text/plain",
///   content: <<"Hello, world!":utf8>>
/// )
/// 
/// simulate.request(http.Post, "/upload")
/// |> simulate.multipart_body([#("user", "joe")], [#("file", file)])
/// ```
/// 
pub fn multipart_body(
  request: Request,
  values values: List(#(String, String)),
  files files: List(#(String, FileUpload)),
) -> Request {
  let boundary = crypto.strong_random_bytes(16) |> bit_array.base16_encode
  let body_data = build_multipart_body(values, files, boundary)
  let body = wisp.create_canned_connection(body_data, default_secret_key_base)

  request
  |> request.set_body(body)
  |> request.set_header(
    "content-type",
    "multipart/form-data; boundary=" <> boundary,
  )
}

fn build_multipart_body(
  form_values: List(#(String, String)),
  files: List(#(String, FileUpload)),
  boundary: String,
) -> BitArray {
  // Append form parts
  let body =
    list.fold(form_values, <<>>, fn(acc, field) {
      let #(name, value) = field
      // Append this part to accumulator
      <<
        acc:bits,
        "--":utf8,
        boundary:utf8,
        "\r\n":utf8,
        "Content-Disposition: form-data; name=\"":utf8,
        name:utf8,
        "\"\r\n":utf8,
        "\r\n":utf8,
        value:utf8,
        "\r\n":utf8,
      >>
    })
    |> list.fold(files, _, fn(acc, file) {
      // Append this file part to accumulator
      <<
        acc:bits,
        "--":utf8,
        boundary:utf8,
        "\r\n":utf8,
        "Content-Disposition: form-data; name=\"":utf8,
        file.0:utf8,
        "\"; filename=\"":utf8,
        { file.1 }.file_name:utf8,
        "\"\r\n":utf8,
        "Content-Type: ":utf8,
        { file.1 }.content_type:utf8,
        "\r\n":utf8,
        "\r\n":utf8,
        { file.1 }.content:bits,
        "\r\n":utf8,
      >>
    })

  // Append final boundary
  <<body:bits, "--":utf8, boundary:utf8, "--\r\n":utf8>>
}

/// Read a text body from a response.
///
/// # Panics
///
/// This function will panic if the response body is a file and the file cannot
/// be read, or if it does not contain valid UTF-8.
///
pub fn read_body(response: Response) -> String {
  case response.body {
    Text(tree) -> tree
    Bytes(bytes) -> {
      let data = bytes_tree.to_bit_array(bytes)
      let assert Ok(string) = bit_array.to_string(data)
        as "the response body was non-UTF8 binary data"
      string
    }
    File(path:, offset: 0, limit: None) -> {
      let assert Ok(data) = simplifile.read_bits(path)
        as "the body was a file, but the file could not be read"
      let assert Ok(contents) = bit_array.to_string(data)
        as "the body file was not valid UTF-8"
      contents
    }
    File(path:, offset:, limit:) -> {
      let assert Ok(data) = simplifile.read_bits(path)
        as "the body was a file, but the file could not be read"
      let byte_length =
        limit |> option.unwrap(bit_array.byte_size(data) - offset)
      let assert Ok(slice) = bit_array.slice(data, offset, byte_length)
        as "the body was a file, but the limit and offset were invalid"
      let assert Ok(string) = bit_array.to_string(slice)
        as "the body file range was not valid UTF-8"
      string
    }
    Chunks(yield) -> {
      yielder.fold(yield, "", fn(acc, chunk) {
        let assert Ok(string) =
          bytes_tree.to_bit_array(chunk) |> bit_array.to_string
          as "the response body was non-UTF8 binary data"
        acc <> string
      })
    }
  }
}

/// Read a binary data body from a response.
///
/// # Panics
///
/// This function will panic if the response body is a file and the file cannot
/// be read.
///
pub fn read_body_bits(response: Response) -> BitArray {
  case response.body {
    Bytes(tree) -> bytes_tree.to_bit_array(tree)
    Text(tree) -> <<tree:utf8>>
    File(path:, offset: 0, limit: None) -> {
      let assert Ok(contents) = simplifile.read_bits(path)
        as "the response body was a file, but the file could not be read"
      contents
    }
    File(path:, offset:, limit:) -> {
      let assert Ok(contents) = simplifile.read_bits(path)
        as "the body was a file, but the file could not be read"
      let limit = limit |> option.unwrap(bit_array.byte_size(contents))
      let assert Ok(sliced) = contents |> bit_array.slice(offset, limit)
        as "the body was a file, but the limit and offset were invalid"
      sliced
    }
    Chunks(yield) -> {
      yielder.fold(yield, bit_array.from_string(""), fn(acc, chunk) {
        let data = bytes_tree.to_bit_array(chunk)
        bit_array.append(acc, data)
      })
    }
  }
}

/// Set a header on a request.
/// 
pub fn header(request: Request, name: String, value: String) -> Request {
  request.set_header(request, name, value)
}

/// Set a cookie on the request.
/// 
pub fn cookie(
  request: Request,
  name: String,
  value: String,
  security: wisp.Security,
) -> Request {
  let value = case security {
    wisp.PlainText -> bit_array.base64_encode(<<value:utf8>>, False)
    wisp.Signed -> wisp.sign_message(request, <<value:utf8>>, crypto.Sha512)
  }
  request.set_cookie(request, name, value)
}

/// The default secret key base used for test requests.
/// This should never be used outside of tests.
///
pub const default_secret_key_base: String = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

/// The default host for test requests.
///
pub const default_host: String = "wisp.example.com"

/// The default headers for non-browser requests.
///
pub const default_headers: List(#(String, String)) = [#("host", default_host)]

/// The default headers for browser requests.
///
pub const default_browser_headers: List(#(String, String)) = [
  #("origin", "https://" <> default_host),
  #("host", default_host),
]
