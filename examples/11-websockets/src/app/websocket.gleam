import gleam/erlang/process.{type Selector}
import gleam/function
import gleam/int
import gleam/otp/actor
import wisp.{type Request, type Response}

// The state our websocket will maintain for each connection. We will hold both
// the websocket connection for sending messages to, as well as the counter
// which we will increment each time we receive a websocket message.
pub type State {
  State(websocket: wisp.WsConnection, counter: Int)
}

// Our websocket actor requires some setup functions in order to function
// We need to build out two core functions: on_init and handler.
pub fn ping_counter(_req: Request, ws: wisp.WsCapability) -> Response {
  // We will create our websocket handler type, holding our actor functions.
  // After which we will pass this to the `websocket` function to start the websocket.
  wisp.WsHandler(on_init, handler) |> wisp.websocket(ws)
}

// This handles the start-up of our actor. We need to initialize our default
// state and create a process subject/selector for our application
// to send messages to the websocket if required.
fn on_init(websocket: wisp.WsConnection) -> #(State, Selector(Reset)) {
  // We setup our state type with default values.
  let state = State(websocket: websocket, counter: 0)
  // then send a message to let the client know it is successfully connected.
  "connected" |> process.send(state.websocket, _)

  // Next, we setup a selector, which allows other actors to send to this
  // one.
  let subject = process.new_subject()
  let selector =
    process.new_selector() |> process.selecting(subject, function.identity)

  // And then we start our other example co-process, which will send a reset
  // message every 10 seconds to our websocket.
  process.start(fn() { reset_loop(subject) }, True)

  // Finally returning our state and our selector as a tuple
  #(state, selector)
}

// This handles the message loop for our actor. When a message comes from a
// websocket client (WsText) or from another process (WsCustom via our Selector) we need
// to handle that event.
//
// Our handler will simply respond to any "ping" text message with the count of
// messages received response, while handling resetting the count every 10
// seconds when a custom message is received.
fn handler(
  msg: wisp.WsMessage(Reset),
  state: State,
) -> actor.Next(wisp.WsMessage(Reset), State) {
  // We need to handle the incoming messages to the websocket actor
  case msg {
    // First we handle messages from our websocket client
    wisp.WsText(text) -> {
      // Upon receiving a message, we will increment our actors state counter by one
      let state = State(..state, counter: state.counter + 1)
      case text {
        // If we receive a 'ping' message from the client, the server will now respond the count back.
        "ping" ->
          state.counter |> int.to_string |> process.send(state.websocket, _)
        // If we receive any other text, we will notify the client it is invalid
        _ -> "invalid message" |> process.send(state.websocket, _)
      }
      // Having successfully handled the message, we then begin waiting for another message.
      actor.continue(state)
    }

    // We can have another process or actor in our application send a message
    // our websocket handler/actor. We have currently define this type as
    // `Reset` with a single variant, `Reset` which we will set the counter
    // back to zero and return.
    wisp.WsCustom(Reset) -> {
      let state = State(..state, counter: 0)
      actor.continue(state)
    }

    // We also need to handle our other message types. Our shutdown and closed
    // messages should stop the actor while performing any necessary clean up required
    wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
  }
}

// Our custom internal message type to our actor.
type Reset {
  Reset
}

// A simple loop which sends a reset message to our websocket handler every 10
// seconds indefinitely.
fn reset_loop(websocket_handler: process.Subject(Reset)) -> Nil {
  process.sleep(10_000)
  process.send(websocket_handler, Reset)
  reset_loop(websocket_handler)
}
