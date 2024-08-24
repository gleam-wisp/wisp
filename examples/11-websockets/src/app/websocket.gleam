import gleam/erlang/process.{type Selector}
import gleam/int
import gleam/option.{type Option, None}
import gleam/otp/actor
import wisp.{type Request, type Response}

// The state our websocket will maintain for each connection. We will hold a
// counter which we will increment each time we receive a websocket message.
pub type State {
  State(counter: Int)
}

// Our websocket actor requires some setup functions in order to function
// We need to build out three core functions: handler, on_init and on_close.
pub fn ping_pong(req: Request, ws: wisp.WsCapability(State, String)) -> Response {
  // We will create our websocket handler type, holding our various actor functions.
  // After which we will pass this to the `websocket` function to start the websocket.
  wisp.WsHandler(handler, on_init, on_close)
  |> wisp.websocket(req, ws)
}

// This handles the start-up of our actor. We need to initialize our default
// state and optionally create a process subject/selector for our application
// to send messages to the websocket if required.
fn on_init(conn: wisp.WsConnection) -> #(State, Option(Selector(String))) {
  // We send a message to let the client know it is successfully connected.
  let assert Ok(Nil) = "connected" |> wisp.WsSendText |> conn()
  // Then we setup our state type with default values.
  let state = State(counter: 0)
  // We could optionally then setup a selector, which would allow other actors
  // to send to this one.
  let selector = None

  #(state, selector)
}

// This handles the message loop for our actor. When a message comes from a
// client (WsText) or from another process (WsCustom via our Selector) we need
// to handle that event.
//
// Our handler will simply respond to any "ping" text message with a "pong" response.
fn handler(
  state: State,
  conn: wisp.WsConnection,
  msg: wisp.WsMessage(String),
) -> actor.Next(String, State) {
  // We need to handle the incoming messages to the websocket actor
  case msg {
    // Our client will only send text so this will be the primary message send from the client to the server
    wisp.WsText(text) -> {
      // We assert that our message sent successfully. Though this should
      // typically be handled, such as by closing the socket or logging an error.
      let assert Ok(Nil) = case text {
        // If we receive a 'ping' message from the client, the server will now response 'pong' directly back.
        "ping" -> "pong" |> wisp.WsSendText |> conn()
        // If we receive any other text, we will notify the client it is invalid
        _ -> "invalid message" |> wisp.WsSendText |> conn()
      }
      // After receiving a message, we will increment our actors state counter by one
      let state = State(counter: state.counter + 1)
      // Having successfully handled the message, we then begin waiting for another message.
      actor.continue(state)
    }
    // We also need to handle our other message types. Our shutdown and closed
    // messages should stop the actor and as we are not supporting binary
    // messages, we will assume this is malformed and also close the
    // connection.
    wisp.WsBinary(_) | wisp.WsClosed | wisp.WsShutdown ->
      actor.Stop(process.Normal)

    // Using our custom type, we can have another process or actor in our
    // application send a message to the websocket, which we immediately
    // forward onto the client. We set our selector to None in our on_init, so
    // this will not actually be reachable in our example.
    wisp.WsCustom(text) -> {
      let assert Ok(Nil) = text |> wisp.WsSendText |> conn()
      actor.continue(state)
    }
  }
}

// Here we need to handle any clean-up required when our websocket closes.
// This may involve alerting other actors or simply logging.
fn on_close(state: State) -> Nil {
  let msg =
    "Websocket closed after receiving: "
    <> int.to_string(state.counter)
    <> " messages"
  wisp.log_warning(msg)
}
