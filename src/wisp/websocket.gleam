pub opaque type WebSocketConnection {
  WebSocketConnection(
    send_text: fn(String) -> Result(Nil, WebSocketError),
    send_binary: fn(BitArray) -> Result(Nil, WebSocketError),
    close: fn() -> Result(Nil, WebSocketError),
  )
}

pub type WebSocketError {
  ConnectionClosed
  SendFailed
  InvalidMessage
  WebSocketError(String)
}

pub type WebSocketMessage {
  Text(String)
  Binary(BitArray)
  Closed
  Shutdown
}

pub type WebSocketNext(state) {
  Continue(state)
  Stop
  StopWithError(String)
}

pub opaque type WebSocket {
  WebSocket(
    init: fn(WebSocketConnection) -> WebSocketState,
    handle: fn(WebSocketState, WebSocketMessage, WebSocketConnection) ->
      WebSocketResult,
    close: fn(WebSocketState) -> Nil,
  )
}

pub opaque type WebSocketState {
  WebSocketState(step: fn(WebSocketAction) -> WebSocketResult)
}

type WebSocketAction {
  HandleMessage(WebSocketMessage, WebSocketConnection)
  Close
  GetNext(WebSocketNext(WebSocketState))
}

pub type WebSocketResult {
  ContinueWith(WebSocketState)
  StopNow
  StopWithErrorResult(String)
}

@internal
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

pub fn send_text(
  connection: WebSocketConnection,
  message: String,
) -> Result(Nil, WebSocketError) {
  connection.send_text(message)
}

pub fn send_binary(
  connection: WebSocketConnection,
  message: BitArray,
) -> Result(Nil, WebSocketError) {
  connection.send_binary(message)
}

pub fn close_connection(
  connection: WebSocketConnection,
) -> Result(Nil, WebSocketError) {
  connection.close()
}

pub fn new(
  on_init: fn(WebSocketConnection) -> state,
  on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> WebSocket {
  WebSocket(
    init: fn(connection) {
      on_init(connection)
      |> new_state(on_message, on_close)
    },
    handle:,
    close:,
  )
}

fn handle(
  state: WebSocketState,
  message: WebSocketMessage,
  connection: WebSocketConnection,
) -> WebSocketResult {
  state.step(HandleMessage(message, connection))
}

fn close(state: WebSocketState) -> Nil {
  case state.step(Close) {
    _ -> Nil
  }
}

fn new_state(
  state: state,
  on_message: fn(state, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(state),
  on_close: fn(state) -> Nil,
) -> WebSocketState {
  WebSocketState(step: fn(action) {
    case action {
      HandleMessage(message, connection) -> {
        case on_message(state, message, connection) {
          Continue(state) ->
            ContinueWith(new_state(state, on_message, on_close))
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

@internal
pub fn extract_callbacks(
  ws: WebSocket,
) -> #(
  fn(WebSocketConnection) -> WebSocketState,
  fn(WebSocketState, WebSocketMessage, WebSocketConnection) ->
    WebSocketNext(WebSocketState),
  fn(WebSocketState) -> Nil,
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

fn result_to_next(result: WebSocketResult) -> WebSocketNext(WebSocketState) {
  case result {
    ContinueWith(state) -> Continue(state)
    StopNow -> Stop
    StopWithErrorResult(error) -> StopWithError(error)
  }
}
