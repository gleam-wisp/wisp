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
  Context(ws: wisp.WsCapability(Int, String))
}

fn handle_req(req: wisp.Request, ctx: fn() -> Context) -> wisp.Response {
  let ctx = ctx()
  case wisp.path_segments(req) {
    ["test", "ws"] -> ws_handler(req, ctx)
    _ -> wisp.not_found()
  }
}

fn ws_handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  let on_init = fn(conn: wisp.WsConnection) {
    let assert Ok(Nil) = "Hello, Joe!" |> wisp.WsSendText |> conn()
    #(0, None)
  }
  let handler = fn(state: Int, conn: wisp.WsConnection, msg) {
    case msg {
      wisp.WsText(text) -> {
        let assert Ok(Nil) = case text {
          "ping" | "ping\n" -> "pong" |> wisp.WsSendText |> conn()
          "count" -> state |> int.to_string |> wisp.WsSendText |> conn()
          repeat -> repeat |> wisp.WsSendText |> conn()
        }
        actor.continue(state)
      }
      wisp.WsBinary(_binary) -> actor.continue(state)
      wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
      wisp.WsCustom(_selector) -> actor.continue(state)
    }
  }
  let on_close = fn(_state) { Nil }

  wisp.WsHandler(handler, on_init, on_close)
  |> wisp.websocket(req, ctx.ws)
}
