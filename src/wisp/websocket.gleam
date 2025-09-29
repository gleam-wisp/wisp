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

/// A completely type-safe WebSocket interface that uses existential types
/// to hide the state type while maintaining compile-time type safety.
/// This follows the glinterface pattern of using opaque types and function composition.
pub opaque type WebSocket {
  WebSocket(interface: WebSocketInterface)
}

/// The core interface that encapsulates all WebSocket operations
/// without exposing or requiring knowledge of the internal state type.
type WebSocketInterface {
  WebSocketInterface(
    init: fn(WebSocketConnection) -> WebSocketState,
    handle: fn(WebSocketState, WebSocketMessage, WebSocketConnection) ->
      WebSocketResult,
    close: fn(WebSocketState) -> Nil,
  )
}

/// Opaque state container that hides the actual state type completely
/// while allowing operations on it through function composition.
pub opaque type WebSocketState {
  WebSocketState(step: fn(WebSocketAction) -> WebSocketResult)
}

/// Actions that can be performed on the WebSocket state
type WebSocketAction {
  HandleMessage(WebSocketMessage, WebSocketConnection)
  Close
  GetNext(WebSocketNext(WebSocketState))
}

/// Results from WebSocket operations that maintain type safety
pub type WebSocketResult {
  ContinueWith(WebSocketState)
  StopNow
  StopWithErrorResult(String)
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

/// Create a type-safe WebSocket interface from user handlers.
/// This is the main entry point that captures the user's state type
/// and creates a completely type-safe interface without dynamic casts.
pub fn create(
  on_init: fn(WebSocketConnection) -> state,
  on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> WebSocket {
  WebSocket(interface: WebSocketInterface(
    init: fn(connection) {
      let initial_state = on_init(connection)
      create_state(initial_state, on_message, on_close)
    },
    handle: handle_action,
    close: close_state,
  ))
}

/// Create a type-safe state container that captures the state and operations
/// in closures, eliminating the need for dynamic casts.
fn create_state(
  state: state,
  on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> WebSocketState {
  WebSocketState(step: fn(action) {
    case action {
      HandleMessage(message, connection) -> {
        case on_message(state, message, connection) {
          Continue(new_state) ->
            ContinueWith(create_state(new_state, on_message, on_close))
          Stop -> StopNow
          StopWithError(error) -> StopWithErrorResult(error)
        }
      }
      Close -> {
        on_close(state)
        StopNow
      }
      GetNext(next) ->
        case next {
          Continue(safe_state) -> ContinueWith(safe_state)
          Stop -> StopNow
          StopWithError(error) -> StopWithErrorResult(error)
        }
    }
  })
}

/// Handle an action on the type-safe state
fn handle_action(
  state: WebSocketState,
  message: WebSocketMessage,
  connection: WebSocketConnection,
) -> WebSocketResult {
  state.step(HandleMessage(message, connection))
}

/// Close the type-safe state
fn close_state(state: WebSocketState) -> Nil {
  case state.step(Close) {
    _ -> Nil
  }
}

/// Initialize the type-safe WebSocket
pub fn init(ws: WebSocket, connection: WebSocketConnection) -> WebSocketState {
  ws.interface.init(connection)
}

/// Handle a message
pub fn handle_message(
  ws: WebSocket,
  state: WebSocketState,
  message: WebSocketMessage,
  connection: WebSocketConnection,
) -> WebSocketResult {
  ws.interface.handle(state, message, connection)
}

/// Close the WebSocket
pub fn close_websocket(ws: WebSocket, state: WebSocketState) -> Nil {
  ws.interface.close(state)
}

/// Convert WebSocketResult to standard WebSocketNext for compatibility
pub fn result_to_next(result: WebSocketResult) -> WebSocketNext(WebSocketState) {
  case result {
    ContinueWith(state) -> Continue(state)
    StopNow -> Stop
    StopWithErrorResult(error) -> StopWithError(error)
  }
}

/// Extract the interface callbacks for integration with existing infrastructure.
/// This provides the necessary bridge to work with the current WebSocket system
/// while maintaining complete type safety.
pub fn extract_callbacks(
  ws: WebSocket,
) -> #(
  fn(WebSocketConnection) -> WebSocketState,
  fn(WebSocketState, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(WebSocketState),
  fn(WebSocketState) -> Nil,
) {
  #(
    ws.interface.init,
    fn(state, message, connection) {
      ws.interface.handle(state, message, connection)
      |> result_to_next
    },
    ws.interface.close,
  )
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

/// Create a WebSocket from a standard WebSocketHandler for easy migration
pub fn from_handler(handler: WebSocketHandler(state)) -> WebSocket {
  create(on_init(handler), on_message(handler), on_close(handler))
}

/// Create a standard WebSocketHandler from a WebSocket for compatibility
pub fn to_handler(ws: WebSocket) -> WebSocketHandler(WebSocketState) {
  let #(init_fn, message_fn, close_fn) = extract_callbacks(ws)
  handler(on_init: init_fn, on_message: message_fn, on_close: close_fn)
}
