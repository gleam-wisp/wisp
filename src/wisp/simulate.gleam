import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import simplifile
import wisp.{type Request, type Response, Bytes, File, Text, WebSocket}
import wisp/websocket

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
    WebSocket(_) -> {
      panic as "Cannot read body of WebSocket response - use a WebSocket client instead"
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
    WebSocket(_) -> {
      panic as "Cannot read body of WebSocket response - use a WebSocket client instead"
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

/// Create a WebSocket upgrade request with the necessary headers for testing.
///
pub fn websocket_request(method: http.Method, path: String) -> Request {
  request(method, path)
  |> header("Connection", "Upgrade")
  |> header("Upgrade", "websocket")
  |> header("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
  |> header("Sec-WebSocket-Version", "13")
}

/// Test a WebSocket handler by checking that it returns a WebSocket response.
/// Returns the extracted callbacks for further testing.
///
pub fn expect_websocket_upgrade(
  response: Response,
) -> #(
  fn(websocket.WebSocketConnection) -> dynamic.Dynamic,
  fn(dynamic.Dynamic, websocket.WebSocketMessage, websocket.WebSocketConnection) -> websocket.WebSocketNext(dynamic.Dynamic),
  fn(dynamic.Dynamic) -> Nil,
) {
  case response.body {
    WebSocket(upgrade) -> {
      wisp.websocket_upgrade_callbacks(upgrade)
    }
    _ ->
      panic as "Expected WebSocket response, but got a different response type"
  }
}

/// Simulate a WebSocket connection for testing purposes.
/// This creates a mock WebSocket connection that can be used to test handlers.
///
pub type WebSocketConnection {
  WebSocketConnection(
    sent_texts: List(String),
    sent_binaries: List(BitArray),
    closed: Bool,
  )
}

/// Create a new mock WebSocket connection for testing.
///
pub fn websocket_connection() -> WebSocketConnection {
  WebSocketConnection(sent_texts: [], sent_binaries: [], closed: False)
}

/// Test WebSocket callbacks with a specific message and initial state.
/// Returns the new state and any actions performed on the connection.
///
/// This implementation captures all WebSocket actions (text messages, binary messages,
/// and close operations) in the returned WebSocketConnection for testing purposes.
///
pub fn websocket_message(
  callbacks: #(
    fn(websocket.WebSocketConnection) -> dynamic.Dynamic,
    fn(dynamic.Dynamic, websocket.WebSocketMessage, websocket.WebSocketConnection) -> websocket.WebSocketNext(dynamic.Dynamic),
    fn(dynamic.Dynamic) -> Nil,
  ),
  initial_state: dynamic.Dynamic,
  message: websocket.WebSocketMessage,
  mock_connection: WebSocketConnection,
) -> #(websocket.WebSocketNext(dynamic.Dynamic), WebSocketConnection) {
  let #(_on_init, on_message_fn, _on_close) = callbacks

  // Use the helper function to capture WebSocket actions
  let final_connection =
    capture_websocket_actions(callbacks, initial_state, message, mock_connection)

  // Also get the result by running the handler once more (this is necessary because
  // we need both the return value and the side effects)
  let test_connection =
    websocket.make_connection(
      fn(_text) { Ok(Nil) },
      fn(_binary) { Ok(Nil) },
      fn() { Ok(Nil) },
    )

  let result = on_message_fn(initial_state, message, test_connection)

  #(result, final_connection)
}

/// Test a WebSocket handler directly with a specific message and initial state.
/// This is a legacy function for backward compatibility.
/// Returns the new state and any actions performed on the connection.
///
pub fn websocket_handler_message(
  handler: websocket.WebSocketHandler(state),
  initial_state: state,
  message: websocket.WebSocketMessage,
  mock_connection: WebSocketConnection,
) -> #(websocket.WebSocketNext(state), WebSocketConnection) {
  // Use the helper function to capture WebSocket actions
  let final_connection =
    capture_websocket_handler_actions(handler, initial_state, message, mock_connection)

  // Also get the result by running the handler once more (this is necessary because
  // we need both the return value and the side effects)
  let test_connection =
    websocket.make_connection(
      fn(_text) { Ok(Nil) },
      fn(_binary) { Ok(Nil) },
      fn() { Ok(Nil) },
    )

  let on_message_fn = websocket.on_message(handler)
  let result = on_message_fn(initial_state, message, test_connection)

  #(result, final_connection)
}

// Helper function to capture WebSocket actions using process simulation
fn capture_websocket_actions(
  callbacks: #(
    fn(websocket.WebSocketConnection) -> dynamic.Dynamic,
    fn(dynamic.Dynamic, websocket.WebSocketMessage, websocket.WebSocketConnection) -> websocket.WebSocketNext(dynamic.Dynamic),
    fn(dynamic.Dynamic) -> Nil,
  ),
  initial_state: dynamic.Dynamic,
  message: websocket.WebSocketMessage,
  mock_connection: WebSocketConnection,
) -> WebSocketConnection {
  let #(_on_init, on_message_fn, _on_close) = callbacks

  // Create a reference to track the connection state using Erlang references
  let texts_ref = make_ref_with_value(mock_connection.sent_texts)
  let binaries_ref = make_ref_with_value(mock_connection.sent_binaries)
  let closed_ref = make_ref_with_value(mock_connection.closed)

  let tracking_connection =
    websocket.make_connection(
      // Track text messages
      fn(text) {
        let current_texts = get_ref_value(texts_ref)
        set_ref_value(texts_ref, [text, ..current_texts])
        Ok(Nil)
      },
      // Track binary messages
      fn(binary) {
        let current_binaries = get_ref_value(binaries_ref)
        set_ref_value(binaries_ref, [binary, ..current_binaries])
        Ok(Nil)
      },
      // Track close action
      fn() {
        set_ref_value(closed_ref, True)
        Ok(Nil)
      },
    )

  // Execute the callback with the tracking connection
  let _ = on_message_fn(initial_state, message, tracking_connection)

  // Return the captured state (reversed to maintain order)
  WebSocketConnection(
    sent_texts: list.reverse(get_ref_value(texts_ref)),
    sent_binaries: list.reverse(get_ref_value(binaries_ref)),
    closed: get_ref_value(closed_ref),
  )
}

// Helper function to capture WebSocket handler actions using process simulation
fn capture_websocket_handler_actions(
  handler: websocket.WebSocketHandler(state),
  initial_state: state,
  message: websocket.WebSocketMessage,
  mock_connection: WebSocketConnection,
) -> WebSocketConnection {
  // Create a reference to track the connection state using Erlang references
  let texts_ref = make_ref_with_value(mock_connection.sent_texts)
  let binaries_ref = make_ref_with_value(mock_connection.sent_binaries)
  let closed_ref = make_ref_with_value(mock_connection.closed)

  let tracking_connection =
    websocket.make_connection(
      // Track text messages
      fn(text) {
        let current_texts = get_ref_value(texts_ref)
        set_ref_value(texts_ref, [text, ..current_texts])
        Ok(Nil)
      },
      // Track binary messages
      fn(binary) {
        let current_binaries = get_ref_value(binaries_ref)
        set_ref_value(binaries_ref, [binary, ..current_binaries])
        Ok(Nil)
      },
      // Track close action
      fn() {
        set_ref_value(closed_ref, True)
        Ok(Nil)
      },
    )

  // Execute the handler with the tracking connection
  let on_message_fn = websocket.on_message(handler)
  let _ = on_message_fn(initial_state, message, tracking_connection)

  // Return the captured state (reversed to maintain order)
  WebSocketConnection(
    sent_texts: list.reverse(get_ref_value(texts_ref)),
    sent_binaries: list.reverse(get_ref_value(binaries_ref)),
    closed: get_ref_value(closed_ref),
  )
}

// External Erlang reference functions for mutable state
@external(erlang, "erlang", "make_ref")
fn make_ref() -> dynamic.Dynamic

@external(erlang, "erlang", "put")
fn erlang_put(key: dynamic.Dynamic, value: dynamic.Dynamic) -> dynamic.Dynamic

@external(erlang, "erlang", "get")
fn erlang_get(key: dynamic.Dynamic) -> dynamic.Dynamic

// Helper functions to work with references
fn make_ref_with_value(value: a) -> dynamic.Dynamic {
  let ref = make_ref()
  let _ = erlang_put(ref, unsafe_coerce(value))
  ref
}

fn get_ref_value(ref: dynamic.Dynamic) -> a {
  erlang_get(ref) |> unsafe_coerce
}

fn set_ref_value(ref: dynamic.Dynamic, value: a) -> Nil {
  let _ = erlang_put(ref, unsafe_coerce(value))
  Nil
}

// Unsafe coercion function for dynamic values
@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(value: a) -> b

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
