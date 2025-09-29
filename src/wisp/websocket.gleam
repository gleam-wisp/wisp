/// The WebSocket connection type. This is an opaque type that represents
/// a WebSocket connection and abstracts away the underlying web server
/// implementation.
pub opaque type WebSocketConnection {
  WebSocketConnection(
    send_text: fn(String) -> Result(Nil, WebSocketError),
    send_binary: fn(BitArray) -> Result(Nil, WebSocketError),
    close: fn() -> Result(Nil, WebSocketError),
  )
}

/// Possible errors when working with WebSockets.
pub type WebSocketError {
  /// The connection was closed unexpectedly
  ConnectionClosed
  /// Failed to send a message
  SendFailed
  /// Invalid message format
  InvalidMessage
  /// Generic error with a description
  WebSocketError(String)
}

/// Types of messages that can be received from a WebSocket connection.
pub type WebSocketMessage {
  /// A text message received from the client
  Text(String)
  /// A binary message received from the client
  Binary(BitArray)
  /// The connection was closed by the client
  Closed
  /// The connection was shut down by the server
  Shutdown
}

/// The result of processing a WebSocket message. This determines what
/// happens next in the WebSocket connection lifecycle.
pub type WebSocketNext(state) {
  /// Continue processing with the given state
  Continue(state)
  /// Gracefully close the WebSocket connection
  Stop
  /// Close the WebSocket connection with an error
  StopWithError(String)
}

/// A WebSocket handler contains all the information needed to handle
/// a WebSocket connection. This is a simple, type-safe approach that
/// uses callbacks stored in the handler.
pub opaque type WebSocketHandler(state) {
  WebSocketHandler(
    on_init: fn(WebSocketConnection) -> state,
    on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
      WebSocketNext(state),
    on_close: fn(state) -> Nil,
  )
}

/// Create a WebSocket connection from the underlying web server functions.
/// This is typically called by the web server adapter (like wisp_mist).
pub fn make_connection(
  send_text: fn(String) -> Result(Nil, WebSocketError),
  send_binary: fn(BitArray) -> Result(Nil, WebSocketError),
  close: fn() -> Result(Nil, WebSocketError),
) -> WebSocketConnection {
  WebSocketConnection(
    send_text: send_text,
    send_binary: send_binary,
    close: close,
  )
}

/// Send a text message to the WebSocket client.
pub fn send_text(
  connection: WebSocketConnection,
  message: String,
) -> Result(Nil, WebSocketError) {
  connection.send_text(message)
}

/// Send a binary message to the WebSocket client.
pub fn send_binary(
  connection: WebSocketConnection,
  message: BitArray,
) -> Result(Nil, WebSocketError) {
  connection.send_binary(message)
}

/// Close the WebSocket connection.
pub fn close(connection: WebSocketConnection) -> Result(Nil, WebSocketError) {
  connection.close()
}

/// Helper function to continue processing WebSocket messages.
pub fn continue(state: state) -> WebSocketNext(state) {
  Continue(state)
}

/// Helper function to stop WebSocket processing gracefully.
pub fn stop() -> WebSocketNext(state) {
  Stop
}

/// Helper function to stop WebSocket processing with an error.
pub fn stop_with_error(error: String) -> WebSocketNext(state) {
  StopWithError(error)
}

/// Create a new WebSocket handler.
pub fn handler(
  on_init on_init: fn(WebSocketConnection) -> state,
  on_message on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(state),
  on_close on_close: fn(state) -> Nil,
) -> WebSocketHandler(state) {
  WebSocketHandler(on_init: on_init, on_message: on_message, on_close: on_close)
}

/// Access the on_init function from a WebSocket handler.
/// This is used by web server adapters.
pub fn on_init(
  handler: WebSocketHandler(state),
) -> fn(WebSocketConnection) -> state {
  handler.on_init
}

/// Access the on_message function from a WebSocket handler.
/// This is used by web server adapters.
pub fn on_message(
  handler: WebSocketHandler(state),
) -> fn(state, WebSocketMessage, WebSocketConnection) -> WebSocketNext(state) {
  handler.on_message
}

/// Access the on_close function from a WebSocket handler.
/// This is used by web server adapters.
pub fn on_close(handler: WebSocketHandler(state)) -> fn(state) -> Nil {
  handler.on_close
}
