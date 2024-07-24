import app/chatroom
import app/web
import gleam/erlang/process.{type Selector}
import gleam/function
import gleam/http/request
import gleam/option.{type Option, Some}
import gleam/otp/actor
import wisp.{type Request, type Response}
import wisp/wisp_mist.{type WebsocketConnection}

// We store the chatroom subject in our handlers state so it can forward
// messages from the client to the chatroom actor.
type State {
  State(username: String, chatroom: process.Subject(chatroom.Event))
}

pub fn chat_server(req: Request, ctx: web.Context) -> Response {
  // We get the username from the url query params provided as part of the login
  let assert Ok([#("username", username)]) = request.get_query(req)
  wisp.WebsocketHandler(
    req,
    ctx.ws,
    handler,
    // We add the username and chatroom subject to our on_init function to
    // allow it to put it in the inital state.
    on_init(_, ctx.chatroom, username),
    on_close,
  )
  |> wisp_mist.websocket
}

fn on_init(
  conn: wisp.WebsocketConnection(WebsocketConnection),
  chatroom: process.Subject(chatroom.Event),
  username: String,
) -> #(State, Option(Selector(String))) {
  let assert Ok(Nil) = "connecting..." |> wisp.SendText(conn) |> wisp_mist.send
  let state = State(username, chatroom)
  // We setup a subject which will allow us to receive messages from within our
  // application. We also need to create a Selector, which will allow the
  // handler to listen to both events from the websocket client as well as this
  // newly created subject.
  let subj = process.new_subject()
  let selector =
    process.new_selector() |> process.selecting(subj, function.identity) |> Some

  // We can now notify the chat server that we have connected and pass our
  // username and subject.
  chatroom.Connected(username: username, connection: subj)
  |> process.send(chatroom, _)

  #(state, selector)
}

// This handles the message loop for our actor. When a message comes from a
// client (WsText) or from another process (WsCustom via our Selector) we need
// to handle that event.
//
// Our handler will simply respond to any "ping" text message with a "pong" response.
fn handler(
  state: State,
  conn: wisp.WebsocketConnection(WebsocketConnection),
  msg: wisp.WebsocketMessage(String),
) -> actor.Next(String, State) {
  case msg {
    wisp.WsText(text) -> {
      // When we receieve any string message from the client, we send it onto
      // the chatroom server along with the clients userame.
      chatroom.Message(username: state.username, message: text)
      |> process.send(state.chatroom, _)
      actor.continue(state)
    }
    wisp.WsBinary(_) | wisp.WsClosed | wisp.WsShutdown ->
      actor.Stop(process.Normal)

    // We can now leverage our custom type, which will receive messages from
    // the chatroom server.
    //
    // The chatroom server sends a message to all clients any time it receives
    // a `chatroom.Message` event from any client.
    //
    // As we have configured out `wisp.WebsocketMessage` as a String type, this
    // means the server will only send strings to our handler, which we can
    // then pass straight onto the websocket client.
    wisp.WsCustom(text) -> {
      let assert Ok(Nil) = text |> wisp.SendText(conn) |> wisp_mist.send
      actor.continue(state)
    }
  }
}

// When we close, we notify the chatroom server that we have disconnected to
// allow it to remove our subject from it's list of clients.
fn on_close(state: State) -> Nil {
  chatroom.Disconnected(username: state.username)
  |> process.send(state.chatroom, _)
}
