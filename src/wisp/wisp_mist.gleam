import exception
import gleam/bytes_tree
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response.{type Response as HttpResponse}
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/string_tree
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
    let mist = request.body

    let connection =
      internal.make_connection(mist_body_reader(request), secret_key_base)
    let request = request.set_body(request, connection)

    use <- exception.defer(fn() {
      let assert Ok(_) = wisp.delete_temporary_files(request)
    })

    let response =
      request
      |> handler

    let response = case response {
      response.Response(_, _, body: wisp.ServerSentEvent(subject)) ->
        mist_server_sent_event(request.set_body(request, mist), subject)
      response -> mist_response(response)
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
  |> result.replace_error(Nil)
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
    wisp.Empty -> mist.Bytes(bytes_tree.new())
    wisp.Text(text) -> mist.Bytes(bytes_tree.from_string_tree(text))
    wisp.Bytes(bytes) -> mist.Bytes(bytes)
    wisp.File(path) -> mist_send_file(path)
    wisp.ServerSentEvent(_) -> panic as "todo: should not happen probably"
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
      mist.Bytes(bytes_tree.new())
    }
  }
}

//
// Server Sent Events
//

fn mist_server_sent_event(request, subject) {
  let on_init = fn(subj) { subject(subj) }

  let handler = fn(state, message, connection) {
    let _ = mist_send_event(connection, message)
    actor.continue(state)
  }

  mist.server_sent_events(request, response.new(200), on_init, handler)
}

pub fn mist_send_event(connection, event) {
  let wisp.SSEMessage(data, event, id, retry) = event
  let mist_event = mist.event(string_tree.from_string(data))
  event |> option.map(fn(name) { mist.event_name(mist_event, name) })
  id |> option.map(fn(id) { mist.event_id(mist_event, id) })
  retry
  |> option.map(fn(retry) { mist.event_retry(mist_event, retry) })

  let result = mist.send_event(connection, mist_event)

  case result {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(wisp.UnexpectedSSEError)
  }
}
