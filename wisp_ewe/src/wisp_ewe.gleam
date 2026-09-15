import ewe.{type Request as EweRequest, type Response as EweResponse}
import gleam/http/request
import gleam/http/response
import gleam/option
import gleam/result
import gleam/string
import wisp.{type Request as WispRequest, type Response as WispResponse}
import wisp/internal

fn server(application: wisp.Application(argument)) -> wisp.Server(argument) {
  wisp.Server(start: fn(make_connection) { todo })
}

fn handler(
  secret_key_base: String,
  new_temporary_file: fn() -> String,
) -> fn(EweRequest) -> EweResponse {
  fn(req) {
    let conn =
      internal.make_connection(
        ewe_body_reader(req),
        new_temporary_file,
        secret_key_base,
      )
    let req = request.set_body(req, conn)

    handler(req)
    |> ewe_response
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

fn ewe_response(resp: WispResponse) -> EweResponse {
  case resp.body {
    wisp.Text(text) -> response.set_body(resp, ewe.TextData(text))
    wisp.Bytes(bytes) -> response.set_body(resp, ewe.BytesData(bytes))
    wisp.File(path:, offset:, limit:) ->
      ewe_send_file(resp, path, offset, limit)
  }
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
