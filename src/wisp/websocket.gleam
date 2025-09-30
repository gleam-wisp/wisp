import gleam/erlang/process.{type Selector}
import gleam/option.{type Option}

/// Represents a WebSocket connection that can be used to send messages.
///
/// This opaque type is passed to your handler's callbacks, allowing you to
/// send messages to the client using `send_text` and `send_binary`.
///
/// You cannot construct this type directly - it is provided by the framework
/// when your handler is called.
///
pub opaque type Connection {
  WebSocketConnection(
    send_text: fn(String) -> Result(Nil, WebSocketError),
    send_binary: fn(BitArray) -> Result(Nil, WebSocketError),
    close: fn() -> Result(Nil, WebSocketError),
  )
}

/// Errors that can occur when working with WebSockets.
///
pub type WebSocketError {
  /// The WebSocket connection has been closed.
  ConnectionClosed
  /// Failed to send a message over the WebSocket.
  SendFailed
  /// The message format was invalid.
  InvalidMessage
  /// A custom WebSocket error with a description.
  WebSocketError(String)
}

/// Messages that can be received from a WebSocket client.
///
/// Your `on_message` callback will receive one of these variants to handle
/// different types of incoming messages.
///
pub type Message(custom) {
  /// A text message received from the client.
  Text(String)
  /// A binary message received from the client.
  Binary(BitArray)
  /// The client has closed the connection.
  Closed
  /// The server is shutting down the connection.
  Shutdown
  Custom(custom)
}

/// The result of handling a WebSocket message.
///
/// Return this from your `on_message` callback to indicate whether the
/// connection should continue or stop.
///
pub type Next(state) {
  /// Continue handling messages with the updated state.
  Continue(state)
  /// Stop the WebSocket connection gracefully.
  Stop
  /// Stop the WebSocket connection with an error message.
  StopWithError(String)
}

/// A WebSocket handler that defines the behavior of a WebSocket connection.
///
/// This opaque type is created using `new` and encapsulates the initialization,
/// message handling, and cleanup logic for a WebSocket connection.
///
/// You cannot construct this type directly - use `new` to create a handler.
///
pub opaque type WebSocket(selector_message, state) {
  WebSocket(
    init: fn(Connection) -> #(State(state), Option(Selector(selector_message))),
    handle: fn(State(state), Message(state), Connection) ->
      WebSocketResult(state),
    close: fn(State(state)) -> Nil,
  )
}

/// The internal state of a WebSocket handler.
///
/// This opaque type represents the current state of your WebSocket handler and
/// is managed internally by the framework. Your handler's state (defined in
/// `on_init` and updated in `on_message`) is stored within this type.
///
pub opaque type State(any) {
  WebSocketState(step: fn(WebSocketAction(any)) -> WebSocketResult(any))
}

type WebSocketAction(any) {
  HandleMessage(Message(any), Connection)
  Close
}

type WebSocketResult(any) {
  ContinueWith(State(any))
  StopNow
  StopWithErrorResult(String)
}

@internal
pub fn make_connection(
  send_text: fn(String) -> Result(Nil, WebSocketError),
  send_binary: fn(BitArray) -> Result(Nil, WebSocketError),
  close: fn() -> Result(Nil, WebSocketError),
) -> Connection {
  WebSocketConnection(
    send_text: send_text,
    send_binary: send_binary,
    close: close,
  )
}

/// Send a text message to the WebSocket client.
///
/// This function sends a UTF-8 text message over the WebSocket connection.
/// Call this from your `on_message` or `on_init` callback to send messages
/// to the client.
///
/// ## Example
///
/// ```gleam
/// websocket.new(
///   on_init: fn(_conn) { 0 },
///   on_message: fn(state, message, connection) {
///     case message {
///       websocket.Text(text) -> {
///         let response = "You said: " <> text
///         case websocket.send_text(connection, response) {
///           Ok(_) -> websocket.Continue(state)
///           Error(_) -> websocket.StopWithError("Failed to send message")
///         }
///       }
///       _ -> websocket.Continue(state)
///     }
///   },
///   on_close: fn(_) { Nil },
/// )
/// ```
///
/// ## Returns
///
/// - `Ok(Nil)` - The message was sent successfully
/// - `Error(WebSocketError)` - Failed to send the message
///
pub fn send_text(
  connection: Connection,
  message: String,
) -> Result(Nil, WebSocketError) {
  connection.send_text(message)
}

/// Send a binary message to the WebSocket client.
///
/// This function sends raw binary data over the WebSocket connection. Use this
/// when you need to send non-text data like images, audio, or custom binary
/// protocols.
///
/// ## Example
///
/// ```gleam
/// websocket.new(
///   on_init: fn(_conn) { 0 },
///   on_message: fn(state, message, connection) {
///     case message {
///       websocket.Binary(data) -> {
///         // Echo the binary data back
///         case websocket.send_binary(connection, data) {
///           Ok(_) -> websocket.Continue(state)
///           Error(_) -> websocket.StopWithError("Failed to send binary")
///         }
///       }
///       _ -> websocket.Continue(state)
///     }
///   },
///   on_close: fn(_) { Nil },
/// )
/// ```
///
/// ## Returns
///
/// - `Ok(Nil)` - The message was sent successfully
/// - `Error(WebSocketError)` - Failed to send the message
///
pub fn send_binary(
  connection: Connection,
  message: BitArray,
) -> Result(Nil, WebSocketError) {
  connection.send_binary(message)
}

@internal
pub fn close_connection(connection: Connection) -> Result(Nil, WebSocketError) {
  connection.close()
}

/// Create a new WebSocket handler.
///
/// This function defines the behavior of a WebSocket connection by providing
/// three callbacks:
///
/// - `on_init`: Called when the connection is established. Return a tuple with
///   the initial state for this connection and an optional process selector for
///   handling custom messages.
/// - `on_message`: Called when a message is received. Return `Continue(state)`
///   to keep the connection open with updated state, `Stop` to close gracefully,
///   or `StopWithError(reason)` to close with an error.
/// - `on_close`: Called when the connection is closed. Use this for cleanup.
///
/// ## Example
///
/// ```gleam
/// // A simple echo server that counts messages
/// websocket.new(
///   on_init: fn(_connection) {
///     // Initialize with a count of 0, no custom selector
///     #(0, option.None)
///   },
///   on_message: fn(count, message, connection) {
///     case message {
///       websocket.Text(text) -> {
///         let new_count = count + 1
///         let response = "Message #" <> int.to_string(new_count) <> ": " <> text
///         case websocket.send_text(connection, response) {
///           Ok(_) -> websocket.Continue(new_count)
///           Error(_) -> websocket.StopWithError("Send failed")
///         }
///       }
///       websocket.Binary(data) -> {
///         websocket.send_binary(connection, data)
///         websocket.Continue(count)
///       }
///       websocket.Closed | websocket.Shutdown -> {
///         websocket.Stop
///       }
///     }
///   },
///   on_close: fn(count) {
///     io.println("Connection closed after " <> int.to_string(count) <> " messages")
///   },
/// )
/// ```
///
/// ## Usage with Wisp
///
/// Use this with `wisp.websocket` to handle WebSocket upgrade requests:
///
/// ```gleam
/// pub fn handle_request(request: wisp.Request) -> wisp.Response {
///   case wisp.path_segments(request) {
///     ["ws"] -> {
///       wisp.websocket(
///         request,
///         on_init: fn(_conn) { #(MyState(...), option.None) },
///         on_message: handle_ws_message,
///         on_close: fn(_state) { Nil },
///       )
///     }
///     _ -> wisp.not_found()
///   }
/// }
/// ```
///
pub fn new(
  on_init: fn(Connection) -> #(state, Option(Selector(message))),
  on_message: fn(state, Message(any), Connection) -> Next(state),
  on_close: fn(state) -> Nil,
) -> WebSocket(message, any) {
  WebSocket(
    init: fn(connection) {
      let #(state, selector) = on_init(connection)
      #(new_state(state, on_message, on_close), selector)
    },
    handle:,
    close:,
  )
}

fn handle(
  state: State(any),
  message: Message(any),
  connection: Connection,
) -> WebSocketResult(any) {
  state.step(HandleMessage(message, connection))
}

fn close(state: State(any)) -> Nil {
  case state.step(Close) {
    _ -> Nil
  }
}

fn new_state(
  state: state,
  on_message: fn(state, Message(any), Connection) -> Next(state),
  on_close: fn(state) -> Nil,
) -> State(any) {
  WebSocketState(step: fn(action) {
    case action {
      HandleMessage(message, connection) -> {
        case on_message(state, message, connection) {
          Continue(n_state) ->
            ContinueWith(new_state(n_state, on_message, on_close))
          Stop -> StopNow
          StopWithError(error) -> StopWithErrorResult(error)
        }
      }
      Close -> {
        on_close(state)
        StopNow
      }
    }
  })
}

@internal
pub fn extract_callbacks(
  ws: WebSocket(message, any),
) -> #(
  fn(Connection) -> #(State(any), Option(Selector(message))),
  fn(State(any), Message(any), Connection) -> Next(State(any)),
  fn(State(any)) -> Nil,
) {
  #(
    ws.init,
    fn(state, message, connection) {
      ws.handle(state, message, connection)
      |> result_to_next
    },
    ws.close,
  )
}

fn result_to_next(result: WebSocketResult(any)) -> Next(State(any)) {
  case result {
    ContinueWith(state) -> Continue(state)
    StopNow -> Stop
    StopWithErrorResult(error) -> StopWithError(error)
  }
}
