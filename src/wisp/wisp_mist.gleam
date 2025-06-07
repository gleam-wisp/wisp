import exception
import gleam/bytes_builder
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response.{
  type Response as HttpResponse, Response as HttpResponse,
}
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import gleam/string
import glisten/socket
import mist
import wisp
import wisp/internal

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
///     fn(req, ws) { handle_req(req, fn() { Context(ws) } ) }
///     |> wisp_mist.handler(secret_key_base)
///     |> mist.new
///     |> mist.port(8000)
///     |> mist.start_http
///   process.sleep_forever()
/// }
///
/// type Context {
///   Context(ws: wisp.WsCapability(State, Message))
/// }
///
/// ```
///
pub fn handler(
  handler: fn(wisp.Request, wisp.WsCapability) -> wisp.Response,
  secret_key_base: String,
) -> fn(HttpRequest(mist.Connection)) -> HttpResponse(mist.ResponseData) {
  fn(request: HttpRequest(_)) {
    let mist: mist.Connection = request.body
    let connection =
      internal.make_connection(mist_body_reader(request), secret_key_base)
    let request = request.set_body(request, connection)

    use <- exception.defer(fn() {
      let assert Ok(_) = wisp.delete_temporary_files(request)
    })

    let response =
      request
      |> handler(internal.WsCapability)

    let response = case response {
      HttpResponse(body: wisp.Websocket(subject), ..) ->
        mist_websocket(request.set_body(request, mist), subject)
      response -> response |> mist_response
    }

    response
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
  |> result.nil_error
  |> result.map(fn(chunk) {
    case chunk {
      mist.Done -> internal.ReadingFinished
      mist.Chunk(data, consume) ->
        internal.Chunk(data, fn(size) { wrap_mist_chunk(consume(size)) })
    }
  })
}

fn mist_response(response: wisp.Response) -> HttpResponse(mist.ResponseData) {
  let body = case response.body {
    wisp.Empty -> mist.Bytes(bytes_builder.new())
    wisp.Text(text) -> mist.Bytes(bytes_builder.from_string_builder(text))
    wisp.Bytes(bytes) -> mist.Bytes(bytes)
    wisp.File(path) -> mist_send_file(path)
    // TODO: This scenario isn't possible as we manually handle this response in handler
    wisp.Websocket(..) -> panic as "TODO: shouldn't be possible"
  }
  response
  |> response.set_body(body)
}

fn mist_send_file(path: String) -> mist.ResponseData {
  case mist.send_file(path, offset: 0, limit: option.None) {
    Ok(body) -> body
    Error(error) -> {
      wisp.log_error(string.inspect(error))
      // TODO: return 500
      mist.Bytes(bytes_builder.new())
    }
  }
}

//
// Websockets
//

fn mist_websocket(
  request: HttpRequest(mist.Connection),
  subj: fn(process.Subject(String)) ->
    Result(process.Subject(wisp.WsIntMessage), actor.StartError),
) -> HttpResponse(mist.ResponseData) {
  let on_init = fn(_) {
    let mist_ws = process.new_subject()
    case subj(mist_ws) {
      Ok(subj) -> {
        let selector =
          process.new_selector()
          |> process.selecting(mist_ws, function.identity)
          |> option.Some

        #(subj, selector)
      }
      Error(_) -> todo as "failed to start wisp handler"
    }
  }
  let on_close = fn(state) { process.send(state, wisp.WsIntClosed) }
  let handler = fn(state, conn, msg) {
    // TODO: handle errors!
    let assert Ok(_) = case msg {
      mist.Custom(wisp) -> mist.send_text_frame(conn, wisp)
      msg -> msg |> from_mist_websocket_message |> process.send(state, _) |> Ok
    }
    // TODO: handle stop!
    actor.continue(state)
  }
  mist.websocket(request, handler, on_init, on_close)
}

/// Converts a mist websocket message to a wisp one.
///
fn from_mist_websocket_message(
  msg: mist.WebsocketMessage(a),
) -> wisp.WsIntMessage {
  case msg {
    mist.Text(x) -> wisp.WsIntText(x)
    mist.Binary(x) -> todo as "should we handle binary?"
    mist.Closed -> wisp.WsIntClosed
    mist.Shutdown -> wisp.WsIntShutdown
    mist.Custom(_) -> todo as "we won't send mist.customs to wisp"
  }
}

/// Converts a mist websocket error into a wisp one.
///
fn mist_ws_err(err: socket.SocketReason) -> wisp.WsError {
  case err {
    socket.Closed -> wisp.WsErrClosed
    socket.Timeout -> wisp.WsErrTimeout
    socket.Terminated -> wisp.WsErrTerminated
    e -> wisp.WsErrOther(string.inspect(e))
  }
}
