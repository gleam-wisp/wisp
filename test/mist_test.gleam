import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import gleam/string_builder
import mist
import wisp
import wisp/testing
import wisp/wisp_mist

pub fn websocket_test() {
  webserver()
  process.sleep_forever()
  testing.get("/test/html", [])
}

pub fn webserver() {
  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp_mist.handler(
      fn(req, ws, socket) { handle_req(req, fn() { Context(ws, socket) }) },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

type Context {
  Context(ws: wisp.WsSupported, socket: wisp_mist.Ws)
}

fn handle_req(req: wisp.Request, ctx: fn() -> Context) -> wisp.Response {
  let ctx = ctx()
  case wisp.path_segments(req) {
    ["test", "html"] ->
      wisp.ok()
      |> wisp.html_body(string_builder.from_string("<h1>Hello, Joe!</h1>"))

    ["test", "ws"] -> ws_handler(req, ctx)
    _ -> wisp.not_found()
  }
}

fn ws_handler(req: wisp.Request, ctx: Context) {
  let on_init = fn(conn: wisp.WebsocketConnection(mist.WebsocketConnection)) {
    let assert Ok(_sent) = "hi" |> wisp.SendText(conn) |> wisp_mist.ws_send
    #("", None)
  }
  let handler = fn(state, _conn, msg) {
    case msg {
      wisp.WsText(_text) -> actor.continue(state)
      wisp.WsBinary(_binary) -> actor.continue(state)
      wisp.WsClosed | wisp.WsShutdown -> actor.Stop(process.Normal)
      wisp.WsCustom(_selector) -> actor.continue(state)
    }
  }
  let on_close = fn(_state) { Nil }
  wisp.ws_handler(req, ctx.ws, handler, on_init, on_close)
  |> wisp_mist.websocket(ctx.socket)
}
