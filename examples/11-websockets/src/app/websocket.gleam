import gleam/erlang/process.{type Selector}
import gleam/int
import gleam/option.{type Option, None}
import gleam/otp/actor
import wisp.{type Request, type Response}

// The state our websocket will maintain for each connection. We will hold a
// counter which we will increment each time we receive a websocket message.
pub type State {
  State(websocket: wisp.WsConnection, counter: Int)
}

// Our websocket actor requires some setup functions in order to function
// We need to build out three core functions: handler, on_init and on_close.
pub fn ping_pong(_req: Request, ws: wisp.WsCapability) -> Response {
  // We will create our websocket handler type, holding our various actor functions.
  // After which we will pass this to the `websocket` function to start the websocket.
  wisp.WsHandler(on_init, handler)
  |> wisp.websocket(ws)
}

// This handles the start-up of our actor. We need to initialize our default
// state and create a process subject/selector for our application
// to send messages to the websocket if required.
fn on_init(conn: wisp.WsConnection) -> #(State, Selector(wisp.WsMessage(Nil))) {
  // We send a message to let the client know it is successfully connected.
  "connected" |> process.send(conn, _)
  // Then we setup our state type with default values.
  let state = State(websocket: conn, counter: 0)
  // We then setup a selector, which would allow other actors to send to this
  // one.
  let selector = process.new_selector()

  #(state, selector)
}

// This handles the message loop for our actor. When a message comes from a
// client (WsText) or from another process (WsCustom via our Selector) we need
// to handle that event.
//
// Our handler will simply respond to any "ping" text message with a "pong" response.
fn handler(
  msg: wisp.WsMessage(Nil),
  state: State,
) -> actor.Next(wisp.WsMessage(Nil), State) {
  // We need to handle the incoming messages to the websocket actor
  case msg {
    // Our client will only send text so this will be the primary message send from the client to the server
    wisp.WsText(text) -> {
      // We assert that our message sent successfully. Though this should
      // typically be handled, such as by closing the socket or logging an error.
      case text {
        // If we receive a 'ping' message from the client, the server will now response 'pong' directly back.
        "ping" -> "pong" |> process.send(state.websocket, _)
        // If we receive any other text, we will notify the client it is invalid
        _ -> "invalid message" |> process.send(state.websocket, _)
      }
      // After receiving a message, we will increment our actors state counter by one
      let state = State(..state, counter: state.counter + 1)
      // Having successfully handled the message, we then begin waiting for another message.
      actor.continue(state)
    }

    // We can have another process or actor in our application send a message
    // to the websocket, which we immediately forward onto the client. 
    wisp.WsCustom(Nil) -> {
      //text |> process.send(state.websocket)
      actor.continue(state)
    }

    // We also need to handle our other message types. Our shutdown and closed
    // messages should stop the actor and as we are not supporting binary
    // messages, we will assume this is malformed and also close the
    // connection.
    wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
  }
}
