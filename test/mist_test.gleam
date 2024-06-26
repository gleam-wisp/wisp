import gleam/erlang/process
import gleam/function
import gleam/int
import gleam/option.{None, Some}
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
      fn(req, ws) { handle_req(req, fn() { Context(ws) }) },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

type Context {
  Context(ws: wisp.Ws(mist.Connection))
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
    let assert Ok(_sent) =
      "Hello, Joe!" |> wisp.SendText(conn) |> wisp_mist.send
    #(0, None)
  }
  let handler = fn(state, conn, msg) {
    case msg {
      wisp.WsText(text) -> {
        let assert Ok(_) = case text {
          "ping" -> "pong" |> wisp.SendText(conn) |> wisp_mist.send
          "count" ->
            int.to_string(state) |> wisp.SendText(conn) |> wisp_mist.send
          _ -> Ok(Nil)
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
