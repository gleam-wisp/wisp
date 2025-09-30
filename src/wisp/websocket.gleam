pub opaque type Connection {
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

pub type Message {
  Text(String)
  Binary(BitArray)
  Closed
  Shutdown
}

pub type Next(state) {
  Continue(state)
  Stop
  StopWithError(String)
}

pub opaque type WebSocket {
  WebSocket(
    init: fn(Connection) -> State,
    handle: fn(State, Message, Connection) -> WebSocketResult,
    close: fn(State) -> Nil,
  )
}

pub opaque type State {
  WebSocketState(step: fn(WebSocketAction) -> WebSocketResult)
}

type WebSocketAction {
  HandleMessage(Message, Connection)
  Close
}

pub type WebSocketResult {
  ContinueWith(State)
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

pub fn send_text(
  connection: Connection,
  message: String,
) -> Result(Nil, WebSocketError) {
  connection.send_text(message)
}

pub fn send_binary(
  connection: Connection,
  message: BitArray,
) -> Result(Nil, WebSocketError) {
  connection.send_binary(message)
}

pub fn close_connection(connection: Connection) -> Result(Nil, WebSocketError) {
  connection.close()
}

pub fn new(
  on_init: fn(Connection) -> state,
  on_message: fn(state, Message, Connection) -> Next(state),
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
  state: State,
  message: Message,
  connection: Connection,
) -> WebSocketResult {
  state.step(HandleMessage(message, connection))
}

fn close(state: State) -> Nil {
  case state.step(Close) {
    _ -> Nil
  }
}

fn new_state(
  state: state,
  on_message: fn(state, Message, Connection) -> Next(state),
  on_close: fn(state) -> Nil,
) -> State {
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
  ws: WebSocket,
) -> #(
  fn(Connection) -> State,
  fn(State, Message, Connection) -> Next(State),
  fn(State) -> Nil,
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

fn result_to_next(result: WebSocketResult) -> Next(State) {
  case result {
    ContinueWith(state) -> Continue(state)
    StopNow -> Stop
    StopWithErrorResult(error) -> StopWithError(error)
  }
}
