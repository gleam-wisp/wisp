/// Completely type-safe WebSocket interface using the glinterface pattern.
/// This eliminates all dynamic casts by using higher-order functions and
/// existential types to maintain type safety throughout the connection lifecycle.

import wisp/websocket

/// A completely type-safe WebSocket handler that uses existential types
/// to hide the state type while maintaining compile-time type safety.
/// This follows the glinterface pattern of using opaque types and function composition.
pub opaque type TypeSafeWebSocket {
  TypeSafeWebSocket(
    interface: TypeSafeInterface,
  )
}

/// The core interface that encapsulates all WebSocket operations
/// without exposing or requiring knowledge of the internal state type.
type TypeSafeInterface {
  TypeSafeInterface(
    init: fn(websocket.WebSocketConnection) -> TypeSafeState,
    handle: fn(TypeSafeState, websocket.WebSocketMessage, websocket.WebSocketConnection) ->
      TypeSafeResult,
    close: fn(TypeSafeState) -> Nil,
  )
}

/// Opaque state container that hides the actual state type completely
/// while allowing operations on it through function composition.
pub opaque type TypeSafeState {
  TypeSafeState(
    step: fn(WebSocketAction) -> TypeSafeResult,
  )
}

/// Actions that can be performed on the WebSocket state
pub type WebSocketAction {
  HandleMessage(websocket.WebSocketMessage, websocket.WebSocketConnection)
  Close
  GetNext(websocket.WebSocketNext(TypeSafeState))
}

/// Results from WebSocket operations that maintain type safety
pub type TypeSafeResult {
  Continue(TypeSafeState)
  Stop
  StopWithError(String)
}

/// Create a type-safe WebSocket interface from user handlers.
/// This is the main entry point that captures the user's state type
/// and creates a completely type-safe interface without dynamic casts.
pub fn create(
  on_init: fn(websocket.WebSocketConnection) -> state,
  on_message: fn(state, websocket.WebSocketMessage, websocket.WebSocketConnection) ->
    websocket.WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> TypeSafeWebSocket {
  TypeSafeWebSocket(interface: TypeSafeInterface(
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
  on_message: fn(state, websocket.WebSocketMessage, websocket.WebSocketConnection) ->
    websocket.WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> TypeSafeState {
  TypeSafeState(step: fn(action) {
    case action {
      HandleMessage(message, connection) -> {
        case on_message(state, message, connection) {
          websocket.Continue(new_state) ->
            Continue(create_state(new_state, on_message, on_close))
          websocket.Stop -> Stop
          websocket.StopWithError(error) -> StopWithError(error)
        }
      }
      Close -> {
        on_close(state)
        Stop
      }
      GetNext(next) ->
        case next {
          websocket.Continue(safe_state) -> Continue(safe_state)
          websocket.Stop -> Stop
          websocket.StopWithError(error) -> StopWithError(error)
        }
    }
  })
}

/// Handle an action on the type-safe state
fn handle_action(
  state: TypeSafeState,
  message: websocket.WebSocketMessage,
  connection: websocket.WebSocketConnection,
) -> TypeSafeResult {
  state.step(HandleMessage(message, connection))
}

/// Close the type-safe state
fn close_state(state: TypeSafeState) -> Nil {
  case state.step(Close) {
    _ -> Nil
  }
}

/// Initialize the type-safe WebSocket
pub fn init(
  ws: TypeSafeWebSocket,
  connection: websocket.WebSocketConnection,
) -> TypeSafeState {
  ws.interface.init(connection)
}

/// Handle a message
pub fn handle_message(
  ws: TypeSafeWebSocket,
  state: TypeSafeState,
  message: websocket.WebSocketMessage,
  connection: websocket.WebSocketConnection,
) -> TypeSafeResult {
  ws.interface.handle(state, message, connection)
}

/// Close the connection
pub fn close(ws: TypeSafeWebSocket, state: TypeSafeState) -> Nil {
  ws.interface.close(state)
}

/// Convert TypeSafeResult to standard WebSocketNext for compatibility
pub fn result_to_next(result: TypeSafeResult) -> websocket.WebSocketNext(TypeSafeState) {
  case result {
    Continue(state) -> websocket.Continue(state)
    Stop -> websocket.Stop
    StopWithError(error) -> websocket.StopWithError(error)
  }
}

/// Extract the interface callbacks for integration with existing infrastructure.
/// This provides the necessary bridge to work with the current WebSocket system
/// while maintaining complete type safety.
pub fn extract_callbacks(
  ws: TypeSafeWebSocket,
) -> #(
  fn(websocket.WebSocketConnection) -> TypeSafeState,
  fn(TypeSafeState, websocket.WebSocketMessage, websocket.WebSocketConnection) ->
    websocket.WebSocketNext(TypeSafeState),
  fn(TypeSafeState) -> Nil,
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

/// Create a TypeSafeWebSocket from a standard WebSocketHandler for easy migration
pub fn from_handler(
  handler: websocket.WebSocketHandler(state),
) -> TypeSafeWebSocket {
  create(
    websocket.on_init(handler),
    websocket.on_message(handler),
    websocket.on_close(handler),
  )
}

/// Create a standard WebSocketHandler from a TypeSafeWebSocket for compatibility
pub fn to_handler(ws: TypeSafeWebSocket) -> websocket.WebSocketHandler(TypeSafeState) {
  let #(init_fn, message_fn, close_fn) = extract_callbacks(ws)
  websocket.handler(
    on_init: init_fn,
    on_message: message_fn,
    on_close: close_fn,
  )
}