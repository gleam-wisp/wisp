import gleam/erlang/process
import gleam/http/request
import gleam/int
import gleam/option.{None}
import gleam/otp/actor
import gleeunit/should
import mist
import stratus
import wisp
import wisp/wisp_mist

/// Create a websocket server and client
/// - Websocket sends hello on connect
/// - Client responsed ping
/// - Server responsed pong
/// - Client successfully closes itself
pub fn websocket_test() {
  let subj = process.new_subject()
  let assert Ok(_) = webserver()
  process.sleep(200)
  process.start(fn() { send_ping(subj) }, False)
  process.receive(subj, 200)
  |> should.equal(Ok(Nil))
}

// Websocket Client

fn send_ping(subj: process.Subject(Nil)) {
  let assert Ok(req) = request.to("http://127.0.0.1:8000/test/ws")
  let on_init = fn() { #(Nil, None) }
  let handler = fn(msg, state, conn) {
    let assert Ok(_) = case msg {
      stratus.Text(text) -> {
        case text {
          "Hello, Joe!" -> "ping" |> stratus.send_text_message(conn, _)
          "pong" -> stratus.close(conn)
          _ -> panic as "unknown text message"
        }
      }
      _ -> panic as "unimplemented"
    }
    actor.continue(state)
  }
  let builder =
    stratus.websocket(req, on_init, handler)
    |> stratus.on_close(fn(_) { process.send(subj, Nil) })
  let assert Ok(_) = stratus.initialize(builder)
  process.sleep_forever()
}

// Websocket server

fn webserver() {
  let secret_key_base = wisp.random_string(64)
  fn(req, ws) { handle_req(req, fn() { Context(ws) }) }
  |> wisp_mist.handler(secret_key_base)
  |> mist.new
  |> mist.port(8000)
  |> mist.start_http
}

type Context {
  Context(ws: wisp.WsCapability)
}

fn handle_req(req: wisp.Request, ctx: fn() -> Context) -> wisp.Response {
  let ctx = ctx()
  case wisp.path_segments(req) {
    ["test", "ws"] -> ws_handler(req, ctx)
    ["test", "ws2"] -> ws_handler2(req, ctx)
    _ -> wisp.not_found()
  }
}

// Websocket handler

fn ws_handler(_req: wisp.Request, ctx: Context) -> wisp.Response {
  wisp.WsHandler(on_init: on_init, handler: handler) |> wisp.websocket(ctx.ws)
}

type State {
  State(ws: wisp.WsConnection)
}

fn on_init(ws: wisp.WsConnection) -> #(State, process.Selector(String)) {
  "Hello, Joe!" |> process.send(ws, _)
  #(State(ws), process.new_selector())
}

fn handler(
  msg: wisp.WsMessage,
  state: State,
) -> actor.Next(wisp.WsMessage, State) {
  case msg {
    wisp.WsText(text) -> {
      case text {
        "ping" | "ping\n" -> "pong" |> process.send(state.ws, _)
        repeat -> repeat |> process.send(state.ws, _)
      }
      actor.continue(state)
    }
    wisp.WsCustom(_text) -> actor.continue(state)
    wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
  }
}

// Different websocket handler with different state type

fn ws_handler2(_req: wisp.Request, ctx: Context) -> wisp.Response {
  wisp.WsHandler(on_init: on_init2, handler: handler2) |> wisp.websocket(ctx.ws)
}

type State2 {
  State2(ws: wisp.WsConnection, count: Int)
}

fn on_init2(ws: wisp.WsConnection) -> #(State2, process.Selector(String)) {
  #(State2(ws, 0), process.new_selector())
}

fn handler2(
  msg: wisp.WsMessage,
  state: State2,
) -> actor.Next(wisp.WsMessage, State2) {
  case msg {
    wisp.WsText(text) -> {
      let state = case text {
        "count" | "count\n" -> {
          state.count |> int.to_string |> process.send(state.ws, _)
          state
        }
        _other -> State2(..state, count: state.count + 1)
      }
      actor.continue(state)
    }
    wisp.WsCustom(_text) -> actor.continue(state)
    wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
  }
}
