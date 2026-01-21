import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/uri
import simplifile
import wisp.{type Request, type Response, Bytes, File, Text}
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
    wisp.WebSocket(_) -> {
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
    wisp.WebSocket(_) -> {
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

/// Create a websocket upgrade request with proper headers.
///
/// This creates a request that simulates a WebSocket upgrade handshake by
/// setting the necessary headers: `connection`, `upgrade`, `sec-websocket-key`,
/// and `sec-websocket-version`.
///
/// ## Example
///
/// ```gleam
/// let request = simulate.websocket_request(http.Get, "/chat")
/// let response = handle_request(request)
///
/// case response.body {
///   wisp.WebSocket(upgrade) -> {
///     let handler = wisp.upgrade_to_websocket(upgrade)
///     // Test the websocket handler
///   }
///   _ -> panic as "Expected WebSocket upgrade"
/// }
/// ```
///
pub fn websocket_request(method: http.Method, path: String) -> Request {
  request(method, path)
  |> header("connection", "Upgrade")
  |> header("upgrade", "websocket")
  |> header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
  |> header("sec-websocket-version", "13")
}

/// A websocket mock for testing websocket handlers.
///
/// This opaque type represents a test websocket connection that captures all
/// messages sent by the handler. It maintains the handler's state and tracks
/// all text and binary messages sent through the connection.
///
/// You cannot construct this type directly - use `create_websocket` to create
/// a test websocket from a websocket handler.
///
/// ## Functions
///
/// - `create_websocket` - Create a new test websocket
/// - `send_websocket_text` - Send a text message to the handler
/// - `send_websocket_binary` - Send a binary message to the handler
/// - `websocket_sent_text_messages` - Get all text messages sent by the handler
/// - `websocket_sent_binary_messages` - Get all binary messages sent by the handler
/// - `reset_websocket` - Reset to initial state
/// - `close_websocket` - Close the connection
///
pub opaque type WebSocket(selector_message, state) {
  WebSocket(
    websocket: websocket.WebSocket(selector_message, state),
    connection: websocket.Connection,
    state: websocket.State(state),
    subject: process.Subject(WebSocketMessage(state)),
  )
}

/// Internal state for the websocket mock actor
type WebSocketState(state) {
  State(
    state: option.Option(websocket.State(state)),
    sent_text_messages: List(String),
    sent_binary_messages: List(BitArray),
    closed: Bool,
  )
}

/// Messages that can be sent to the mock websocket actor
type WebSocketMessage(state) {
  SendText(String)
  SendBinary(BitArray)
  Close(websocket.State(state))
  GetSentTextMessages(reply_with: process.Subject(List(String)))
  GetSentBinaryMessages(reply_with: process.Subject(List(BitArray)))
  Reset(state: websocket.State(state))
  SetState(state: websocket.State(state))
  GetState(reply_with: process.Subject(websocket.State(state)))
  IsClosed(reply_with: process.Subject(Bool))
}

/// Create a new websocket mock for testing.
///
/// This function creates a test websocket that captures all messages sent by the
/// handler, allowing you to verify the handler's behavior without needing a real
/// WebSocket connection. The mock automatically tracks text and binary messages
/// sent through the connection.
///
/// ## Example
///
/// ```gleam
/// let handler = websocket.new(
///   on_init: fn(_conn) { 0 },
///   on_message: fn(state, message, connection) {
///     case message {
///       websocket.Text(text) -> {
///         websocket.send_text(connection, "Echo: " <> text)
///         websocket.Continue(state + 1)
///       }
///       _ -> websocket.Continue(state)
///     }
///   },
///   on_close: fn(_state) { Nil },
/// )
///
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
/// let assert ["Echo: Hello"] = simulate.websocket_sent_text_messages(ws)
/// ```
///
/// ## Returns
///
/// - `Ok(WebSocket)` - A test websocket that can be used with other simulate functions
/// - `Error(actor.StartError)` - If the underlying actor fails to start
///
pub fn create_websocket(
  handler websocket: websocket.WebSocket(selector_message, state),
) -> Result(WebSocket(selector_message, state), actor.StartError) {
  let #(init, _, stop) = websocket.extract_callbacks(websocket)

  use started <- result.try(
    actor.new(State(
      state: option.None,
      sent_text_messages: [],
      sent_binary_messages: [],
      closed: False,
    ))
    |> actor.on_message(handle_message)
    |> actor.start,
  )

  let connection =
    websocket.make_connection(
      fn(text) {
        process.send(started.data, SendText(text))
        Ok(Nil)
      },
      fn(binary) {
        process.send(started.data, SendBinary(binary))
        Ok(Nil)
      },
      fn() {
        let state = process.call(started.data, 1000, GetState)
        stop(state)
        Ok(Nil)
      },
    )
  let #(state, _selector) = init(connection)
  process.send(started.data, SetState(state))
  let ws_instance =
    WebSocket(
      websocket: websocket,
      connection: connection,
      state: state,
      subject: started.data,
    )
  Ok(ws_instance)
}

/// Handle messages sent to the mock websocket actor
fn handle_message(
  state: WebSocketState(state),
  message: WebSocketMessage(state),
) -> actor.Next(WebSocketState(state), WebSocketMessage(state)) {
  case message {
    SendText(text) -> {
      let new_state = case state.closed {
        True -> state
        False ->
          State(..state, sent_text_messages: [text, ..state.sent_text_messages])
      }
      actor.continue(new_state)
    }
    SendBinary(binary) -> {
      let new_state = case state.closed {
        True -> state
        False ->
          State(..state, sent_binary_messages: [
            binary,
            ..state.sent_binary_messages
          ])
      }
      actor.continue(new_state)
    }
    Close(_) -> {
      let new_state = State(..state, closed: True)
      actor.continue(new_state)
    }
    GetSentTextMessages(reply_with) -> {
      process.send(reply_with, list.reverse(state.sent_text_messages))
      actor.continue(state)
    }
    GetSentBinaryMessages(reply_with) -> {
      process.send(reply_with, list.reverse(state.sent_binary_messages))
      actor.continue(state)
    }
    Reset(new_state) -> {
      let new_state =
        State(
          state: option.Some(new_state),
          sent_text_messages: [],
          sent_binary_messages: [],
          closed: False,
        )
      actor.continue(new_state)
    }
    SetState(new_state) -> {
      let new_state = State(..state, state: Some(new_state))
      actor.continue(new_state)
    }
    GetState(reply_with:) -> {
      let assert Some(s) = state.state
      process.send(reply_with, s)
      actor.continue(state)
    }
    IsClosed(reply_with:) -> {
      process.send(reply_with, state.closed)
      actor.continue(state)
    }
  }
}

/// Get all text messages that have been sent by the websocket handler.
///
/// Messages are returned in the order they were sent. This is useful for
/// verifying that your handler sends the expected messages in response to
/// incoming messages.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "World")
///
/// let messages = simulate.websocket_sent_text_messages(ws)
/// assert messages == ["Response 1", "Response 2"]
/// ```
///
pub fn websocket_sent_text_messages(
  websocket: WebSocket(selector_message, state),
) -> List(String) {
  process.call(websocket.subject, 1000, GetSentTextMessages)
}

/// Get all binary messages that have been sent by the websocket handler.
///
/// Messages are returned in the order they were sent. This is useful for
/// verifying that your handler sends the expected binary data in response to
/// incoming messages.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_binary(ws, <<1, 2, 3>>)
///
/// let messages = simulate.websocket_sent_binary_messages(ws)
/// assert messages == [<<1, 2, 3>>]
/// ```
///
pub fn websocket_sent_binary_messages(
  websocket: WebSocket(selector_message, state),
) -> List(BitArray) {
  process.call(websocket.subject, 1000, GetSentBinaryMessages)
}

/// Reset the websocket to its initial state, clearing all captured messages.
///
/// This calls the handler's `on_init` callback again and clears the list of
/// sent messages. The websocket is also marked as not closed, allowing you to
/// send messages again after a close.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
/// let assert ["Response"] = simulate.websocket_sent_text_messages(ws)
///
/// // Reset to initial state
/// let ws = simulate.reset_websocket(ws)
/// let assert [] = simulate.websocket_sent_text_messages(ws)
///
/// // Can send messages again from a clean slate
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello again")
/// ```
///
pub fn reset_websocket(
  websocket: WebSocket(selector_message, state),
) -> WebSocket(selector_message, state) {
  let WebSocket(websocket: internal_websocket, connection:, state: _, subject:) =
    websocket
  let #(init, _, _) = websocket.extract_callbacks(internal_websocket)
  let #(state, _selector) = init(connection)
  process.send(subject, Reset(state))
  WebSocket(websocket: internal_websocket, connection:, state:, subject:)
}

/// Simulate sending a text message to the websocket handler.
///
/// This calls the handler's `on_message` callback with a `Text` message. The
/// handler's state is updated based on the callback's response. Any messages
/// sent by the handler can be retrieved using `websocket_sent_text_messages`
/// or `websocket_sent_binary_messages`.
///
/// If the websocket has been closed, this function returns the websocket
/// unchanged without calling the handler.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
/// let assert ["Echo: Hello"] = simulate.websocket_sent_text_messages(ws)
/// ```
///
/// ## Returns
///
/// - `Ok(WebSocket)` - The websocket with updated state
/// - `Error(Nil)` - If the handler returns `Stop` or `StopWithError`
///
pub fn send_websocket_text(
  ws: WebSocket(selector_message, state),
  message: String,
) -> Result(WebSocket(selector_message, state), Nil) {
  let WebSocket(websocket:, state:, connection:, subject:) = ws
  let is_closed = process.call(subject, 1000, IsClosed)
  case is_closed {
    True -> Ok(ws)
    False -> {
      let #(_, handle, _) = websocket.extract_callbacks(websocket)
      case handle(state, websocket.Text(message), connection) {
        websocket.Continue(state) -> {
          process.send(subject, SetState(state))
          Ok(WebSocket(websocket:, state:, connection:, subject:))
        }
        websocket.Stop -> Error(Nil)
        websocket.StopWithError(_) -> Error(Nil)
      }
    }
  }
}

/// Simulate sending a binary message to the websocket handler.
///
/// This calls the handler's `on_message` callback with a `Binary` message. The
/// handler's state is updated based on the callback's response. Any messages
/// sent by the handler can be retrieved using `websocket_sent_text_messages`
/// or `websocket_sent_binary_messages`.
///
/// If the websocket has been closed, this function returns the websocket
/// unchanged without calling the handler.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_binary(ws, <<1, 2, 3>>)
/// let assert [<<1, 2, 3>>] = simulate.websocket_sent_binary_messages(ws)
/// ```
///
/// ## Returns
///
/// - `Ok(WebSocket)` - The websocket with updated state
/// - `Error(Nil)` - If the handler returns `Stop` or `StopWithError`
///
pub fn send_websocket_binary(
  ws: WebSocket(selector_message, state),
  message: BitArray,
) -> Result(WebSocket(selector_message, state), Nil) {
  let WebSocket(websocket:, state:, connection:, subject:) = ws
  let is_closed = process.call(subject, 1000, IsClosed)
  case is_closed {
    True -> Ok(ws)
    False -> {
      let #(_, handle, _) = websocket.extract_callbacks(websocket)
      case handle(state, websocket.Binary(message), connection) {
        websocket.Continue(state) -> {
          process.send(subject, SetState(state))
          Ok(WebSocket(websocket:, state:, connection:, subject:))
        }
        websocket.Stop -> Error(Nil)
        websocket.StopWithError(_) -> Error(Nil)
      }
    }
  }
}

/// Simulate closing the websocket connection.
///
/// This calls the handler's `on_close` callback with the current handler state.
/// After closing, any subsequent calls to `send_websocket_text` or
/// `send_websocket_binary` will be ignored without calling the handler.
///
/// Use `reset_websocket` to re-open the connection for further testing.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ws) = simulate.create_websocket(handler)
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
///
/// // Close the connection
/// let assert Ok(Nil) = simulate.close_websocket(ws)
///
/// // Further messages are ignored
/// let assert Ok(ws) = simulate.send_websocket_text(ws, "After close")
/// let assert ["Response 1"] = simulate.websocket_sent_text_messages(ws)
/// ```
///
/// ## Returns
///
/// - `Ok(Nil)` - If the connection was closed successfully
/// - `Error(WebSocketError)` - If closing the connection failed
///
pub fn close_websocket(
  websocket_arg: WebSocket(selector_message, state),
) -> Result(Nil, websocket.WebSocketError) {
  let WebSocket(websocket: _, state: _, connection:, subject:) = websocket_arg
  let current_state = process.call(subject, 1000, GetState)
  process.send(subject, Close(current_state))
  websocket.close_connection(connection)
}
