import gleam/erlang/process
import gleam/http/request
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import gleeunit/should
import mist
import stratus
import wisp
import wisp/wisp_mist

/// Create a websocket server and client
/// Websocket sends hello on connect
/// Client responsed ping
/// server responsed pong
/// client successfully closes itself
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
  |> io.debug
}

type Context {
  Context(ws: wisp.Ws(wisp_mist.Connection))
}

fn handle_req(req: wisp.Request, ctx: fn() -> Context) -> wisp.Response {
  let ctx = ctx()
  case wisp.path_segments(req) {
    ["test", "ws"] -> ws_handler(req, ctx)
    _ -> wisp.not_found()
  }
}

fn ws_handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  let on_init = fn(
    conn: wisp.WebsocketConnection(wisp_mist.WebsocketConnection),
  ) {
    let assert Ok(_sent) =
      "Hello, Joe!" |> wisp.SendText(conn) |> wisp_mist.send
    #(0, None)
  }
  let handler = fn(state, conn, msg) {
    case msg {
      wisp.WsText(text) -> {
        let assert Ok(_) = case text {
          "ping" | "ping\n" -> "pong" |> wisp.SendText(conn) |> wisp_mist.send
          "count" ->
            int.to_string(state) |> wisp.SendText(conn) |> wisp_mist.send
          repeat -> repeat |> wisp.SendText(conn) |> wisp_mist.send
        }
        let state = state + 1
        actor.continue(state)
      }
      wisp.WsBinary(_binary) -> actor.continue(state)
      wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
      wisp.WsCustom(_selector) -> actor.continue(state)
    }
  }
  let on_close = fn(_state) { Nil }
  wisp.WebsocketHandler(req, ctx.ws, handler, on_init, on_close)
  |> wisp_mist.websocket
}
