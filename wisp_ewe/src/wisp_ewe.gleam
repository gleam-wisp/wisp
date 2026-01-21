import ewe.{type Request as EweRequest, type Response as EweResponse}
import exception
import gleam/http/request
import gleam/http/response
import gleam/option
import gleam/result
import gleam/string
import wisp.{type Request as WispRequest, type Response as WispResponse}
import wisp/internal
import wisp/websocket

/// Convert a Wisp request handler into a function that can be run with the Ewe
/// web server.
///
/// # Examples
///
/// ```gleam
/// pub fn main() {
///   let secret_key_base = "..."
///   let assert Ok(_) =
///     handle_request
///     |> wisp_ewe.handler(secret_key_base)
///     |> ewe.new
///     |> ewe.listening(port: 8000)
///     |> ewe.start
/// 
///   process.sleep_forever()
/// }
/// ```
///
/// The secret key base is used for signing and encryption. To be able to
/// verify and decrypt messages you will need to use the same key each time
/// your program is run. Keep this value secret! Malicious people with this
/// value will likely be able to hack your application.
///
pub fn handler(
  handler: fn(WispRequest) -> WispResponse,
  secret_key_base: String,
) -> fn(EweRequest) -> EweResponse {
  fn(ewe_request) {
    let conn =
      internal.make_connection(ewe_body_reader(ewe_request), secret_key_base)
    let wisp_request = request.set_body(ewe_request, conn)

    use <- exception.defer(fn() {
      let assert Ok(_) = wisp.delete_temporary_files(wisp_request)
    })

    let response = handler(wisp_request)

    // Handle WebSocket upgrade specially
    case response.body {
      wisp.WebSocket(upgrade) -> ewe_websocket_upgrade(ewe_request, upgrade)
      wisp.Text(text) -> response.set_body(response, ewe.TextData(text))
      wisp.Bytes(bytes) -> response.set_body(response, ewe.BytesData(bytes))
      wisp.File(path:, offset:, limit:) ->
        ewe_send_file(response, path, offset, limit)
    }
  }
}

fn ewe_body_reader(req: EweRequest) -> internal.Reader {
  case ewe.stream_body(req) {
    Ok(consumer) -> wrap_ewe_consumer(consumer)
    Error(_) -> fn(_) { Ok(internal.ReadingFinished) }
  }
}

fn wrap_ewe_consumer(consumer: ewe.Consumer) -> internal.Reader {
  fn(size) { wrap_ewe_chunk(consumer(size)) }
}

fn wrap_ewe_chunk(
  chunk: Result(ewe.Stream, ewe.BodyError),
) -> Result(internal.Read, Nil) {
  result.replace_error(chunk, Nil)
  |> result.map(fn(chunk) {
    case chunk {
      ewe.Consumed(data:, next: consumer) ->
        internal.Chunk(data, wrap_ewe_consumer(consumer))
      ewe.Done -> internal.ReadingFinished
    }
  })
}

fn ewe_send_file(
  resp: WispResponse,
  path: String,
  offset: Int,
  limit: option.Option(Int),
) -> EweResponse {
  case ewe.file(path, offset: option.Some(offset), limit:) {
    Ok(file) -> response.set_body(resp, file)
    Error(error) -> {
      string.inspect(error)
      |> wisp.log_error()

      response.new(500) |> response.set_body(ewe.Empty)
    }
  }
}

fn ewe_websocket_upgrade(
  request: EweRequest,
  upgrade: wisp.WebSocketUpgrade,
) -> EweResponse {
  // Recover the type-erased WebSocket handler
  let ws = wisp.recover(upgrade)

  // Extract the callbacks from the handler
  let #(on_init, on_message, on_close) = websocket.extract_callbacks(ws)

  // Create ewe websocket response
  ewe.upgrade_websocket(
    request,
    on_init: fn(ewe_connection, selector) {
      // Create wisp connection from ewe connection
      let wisp_connection =
        websocket.make_connection(
          fn(text) {
            ewe.send_text_frame(ewe_connection, text)
            |> result.map_error(fn(_) { websocket.SendFailed })
          },
          fn(binary) {
            ewe.send_binary_frame(ewe_connection, binary)
            |> result.map_error(fn(_) { websocket.SendFailed })
          },
          fn() { Ok(Nil) },
        )

      let #(state, opt_selector) = on_init(wisp_connection)

      // Use the provided selector if there's one from wisp handler,
      // otherwise use the default selector
      let final_selector = case opt_selector {
        option.Some(s) -> s
        option.None -> selector
      }

      #(state, final_selector)
    },
    handler: fn(ewe_connection, state, message) {
      // Create wisp connection for the handler
      let wisp_connection =
        websocket.make_connection(
          fn(text) {
            ewe.send_text_frame(ewe_connection, text)
            |> result.map_error(fn(_) { websocket.SendFailed })
          },
          fn(binary) {
            ewe.send_binary_frame(ewe_connection, binary)
            |> result.map_error(fn(_) { websocket.SendFailed })
          },
          fn() { Ok(Nil) },
        )

      // Convert ewe message to wisp message
      let wisp_message = case message {
        ewe.Text(text) -> websocket.Text(text)
        ewe.Binary(binary) -> websocket.Binary(binary)
        ewe.User(custom) -> websocket.Custom(custom)
      }

      // Call wisp handler and convert result
      case on_message(state, wisp_message, wisp_connection) {
        websocket.Continue(new_state) -> ewe.websocket_continue(new_state)
        websocket.Stop -> ewe.websocket_stop()
        websocket.StopWithError(reason) -> ewe.websocket_stop_abnormal(reason)
      }
    },
    on_close: fn(_ewe_connection, state) { on_close(state) },
  )
}
