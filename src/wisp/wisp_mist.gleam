import exception
import gleam/bytes_tree
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response.{type Response as HttpResponse}
import gleam/option
import gleam/result
import gleam/string
import mist
import wisp
import wisp/internal
import wisp/websocket

//
// Running the server
//

/// Convert a Wisp request handler into a function that can be run with the Mist
/// web server.
///
/// # Examples
///
/// ```gleam
/// pub fn main() {
///   let secret_key_base = "..."
///   let assert Ok(_) =
///     handle_request
///     |> wisp_mist.handler(secret_key_base)
///     |> mist.new
///     |> mist.port(8000)
///     |> mist.start_http
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
  handler: fn(wisp.Request) -> wisp.Response,
  secret_key_base: String,
) -> fn(HttpRequest(mist.Connection)) -> HttpResponse(mist.ResponseData) {
  fn(request: HttpRequest(_)) {
    let connection =
      internal.make_connection(mist_body_reader(request), secret_key_base)
    let wisp_request = request.set_body(request, connection)

    use <- exception.defer(fn() {
      let assert Ok(_) = wisp.delete_temporary_files(wisp_request)
    })

    let response = handler(wisp_request)

    // Handle WebSocket upgrade specially
    case response.body {
      wisp.WebSocket(upgrade) -> {
        // Extract the handler from the opaque wrapper and convert to mist WebSocket response
        mist_websocket_upgrade(request, upgrade)
      }
      wisp.Text(text) ->
        response
        |> response.set_body(mist.Bytes(bytes_tree.from_string(text)))
      wisp.Bytes(bytes) -> response |> response.set_body(mist.Bytes(bytes))
      wisp.File(path:, offset:, limit:) ->
        response |> response.set_body(mist_send_file(path, offset, limit))
    }
  }
}

fn mist_body_reader(request: HttpRequest(mist.Connection)) -> internal.Reader {
  case mist.stream(request) {
    Error(_) -> fn(_) { Ok(internal.ReadingFinished) }
    Ok(stream) -> fn(size) { wrap_mist_chunk(stream(size)) }
  }
}

fn wrap_mist_chunk(
  chunk: Result(mist.Chunk, mist.ReadError),
) -> Result(internal.Read, Nil) {
  chunk
  |> result.replace_error(Nil)
  |> result.map(fn(chunk) {
    case chunk {
      mist.Done -> internal.ReadingFinished
      mist.Chunk(data, consume) ->
        internal.Chunk(data, fn(size) { wrap_mist_chunk(consume(size)) })
    }
  })
}

fn mist_send_file(
  path: String,
  offset: Int,
  limit: option.Option(Int),
) -> mist.ResponseData {
  case mist.send_file(path, offset:, limit:) {
    Ok(body) -> body
    Error(error) -> {
      wisp.log_error(string.inspect(error))
      // TODO: return 500
      mist.Bytes(bytes_tree.new())
    }
  }
}

fn mist_websocket_upgrade(
  request: HttpRequest(mist.Connection),
  upgrade: wisp.WebSocketUpgrade,
) -> HttpResponse(mist.ResponseData) {
  // Extract the callbacks from the opaque wrapper
  let #(on_init_fn, on_message_fn, on_close_fn) =
    wisp.websocket_upgrade_callbacks(upgrade)

  // Use mist.websocket to create the WebSocket response
  mist.websocket(
    request: request,
    on_init: fn(connection) {
      let wisp_connection =
        websocket.make_connection(
          fn(text) {
            mist.send_text_frame(connection, text)
            |> result.replace_error(websocket.SendFailed)
          },
          fn(binary) {
            mist.send_binary_frame(connection, binary)
            |> result.replace_error(websocket.SendFailed)
          },
          fn() { Ok(Nil) },
        )

      #(on_init_fn(wisp_connection), option.None)
    },
    handler: fn(user_state, message, connection) {
      let wisp_connection =
        websocket.make_connection(
          fn(text) {
            mist.send_text_frame(connection, text)
            |> result.replace_error(websocket.SendFailed)
          },
          fn(binary) {
            mist.send_binary_frame(connection, binary)
            |> result.replace_error(websocket.SendFailed)
          },
          fn() { Ok(Nil) },
        )

      let wisp_message = case message {
        mist.Text(text) -> websocket.Text(text)
        mist.Binary(binary) -> websocket.Binary(binary)
        mist.Closed -> websocket.Closed
        mist.Shutdown -> websocket.Shutdown
        mist.Custom(_custom) -> websocket.Closed
      }
      let result = on_message_fn(user_state, wisp_message, wisp_connection)
      case result {
        websocket.Continue(new_state) -> mist.continue(new_state)
        websocket.Stop -> mist.stop()
        websocket.StopWithError(reason) -> mist.stop_abnormal(reason)
      }
    },
    on_close: on_close_fn,
  )
}
