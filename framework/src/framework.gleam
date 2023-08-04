// - [ ] Test helpers
// - [ ] Body reading
//   - [ ] Form data
//   - [ ] Multipart
//   - [ ] Json
//   - [ ] String
//   - [ ] Bit string
// - [ ] Body writing
//   - [x] Html
//   - [x] Json
// - [ ] Static files
// - [ ] Cookies
//   - [ ] Signed cookies
// - [ ] Secret keys
//   - [ ] Key rotation
// - [ ] Sessions
// - [ ] Flash messages
// - [ ] Websockets
// - [ ] CSRF
// - [ ] Project generators
// - [ ] Exception recovery

import gleam/string_builder.{StringBuilder}
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/erlang
import gleam/bool
import gleam/http.{Method}
import gleam/http/request.{Request as HttpRequest}
import gleam/http/response.{Response as HttpResponse}
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import gleam/io
import gleam/int
import mist

//
// Running the server
//

// TODO: test
// TODO: document
pub fn mist_service(
  service: fn(Request) -> Response,
) -> fn(HttpRequest(mist.Connection)) -> HttpResponse(mist.ResponseData) {
  fn(request: HttpRequest(_)) {
    let connection = make_connection(mist_body_reader(request))
    request
    |> request.set_body(connection)
    |> service
    |> mist_response
  }
}

fn make_connection(body_reader: Reader) -> Connection {
  Connection(
    reader: body_reader,
    max_body_size: 8_000_000,
    max_files_size: 32_000_000,
    read_chunk_size: 1_000_000,
  )
}

fn mist_body_reader(request: HttpRequest(mist.Connection)) -> Reader {
  case mist.stream(request) {
    Error(_) -> fn(_) { Ok(ReadingFinished) }
    Ok(stream) -> fn(size) { wrap_mist_chunk(stream(size)) }
  }
}

fn wrap_mist_chunk(
  chunk: Result(mist.Chunk, mist.ReadError),
) -> Result(Read, Nil) {
  chunk
  |> result.nil_error
  |> result.map(fn(chunk) {
    case chunk {
      mist.Done -> ReadingFinished
      mist.Chunk(data, consume) ->
        Chunk(data, fn(size) { wrap_mist_chunk(consume(size)) })
    }
  })
}

fn mist_response(response: Response) -> HttpResponse(mist.ResponseData) {
  let body = case response.body {
    Empty -> mist.Bytes(bit_builder.new())
    Text(text) -> mist.Bytes(bit_builder.from_string_builder(text))
  }
  response
  |> response.set_body(body)
}

//
// Responses
//

pub type ResponseBody {
  Empty
  Text(StringBuilder)
}

/// An alias for a HTTP response containing a `ResponseBody`.
pub type Response =
  HttpResponse(ResponseBody)

// TODO: test
// TODO: document
pub fn html_response(html: StringBuilder, status: Int) -> Response {
  HttpResponse(status, [#("Content-Type", "text/html")], Text(html))
}

// TODO: test
// TODO: document
pub fn html_body(response: Response, html: StringBuilder) -> Response {
  response
  |> response.set_body(Text(html))
  |> response.set_header("content-type", "text/html")
}

// TODO: test
// TODO: document
pub fn method_not_allowed(permitted: List(Method)) -> Response {
  let allowed =
    permitted
    |> list.map(http.method_to_string)
    |> string.join(", ")
  HttpResponse(405, [#("allow", allowed)], Empty)
}

// TODO: test
// TODO: document
pub fn not_found() -> Response {
  HttpResponse(404, [], Empty)
}

// TODO: test
// TODO: document
pub fn bad_request() -> Response {
  HttpResponse(400, [], Empty)
}

// TODO: test
// TODO: document
pub fn entity_too_large() -> Response {
  HttpResponse(413, [], Empty)
}

// TODO: test
// TODO: document
pub fn internal_server_error() -> Response {
  HttpResponse(500, [], Empty)
}

// TODO: test
// TODO: document
pub fn body_to_string_builder(body: ResponseBody) -> StringBuilder {
  case body {
    Empty -> string_builder.new()
    Text(text) -> text
  }
}

// TODO: test
// TODO: document
pub fn body_to_bit_builder(body: ResponseBody) -> BitBuilder {
  case body {
    Empty -> bit_builder.new()
    Text(text) -> bit_builder.from_string_builder(text)
  }
}

//
// Requests
//

pub opaque type Connection {
  Connection(
    reader: Reader,
    // TODO: document these. Cannot be here as this is opaque.
    max_body_size: Int,
    max_files_size: Int,
    read_chunk_size: Int,
  )
}

type Reader =
  fn(Int) -> Result(Read, Nil)

type Read {
  Chunk(BitString, next: Reader)
  ReadingFinished
}

// TODO: test
// TODO: document
pub fn set_max_body_size(request: Request, size: Int) -> Request {
  Connection(..request.body, max_body_size: size)
  |> request.set_body(request, _)
}

// TODO: test
// TODO: document
pub fn set_max_files_size(request: Request, size: Int) -> Request {
  Connection(..request.body, max_files_size: size)
  |> request.set_body(request, _)
}

// TODO: test
// TODO: document
pub fn set_read_chunk_size(request: Request, size: Int) -> Request {
  Connection(..request.body, read_chunk_size: size)
  |> request.set_body(request, _)
}

pub type Request =
  HttpRequest(Connection)

// TODO: test
// TODO: document
pub fn require_method(
  request: HttpRequest(t),
  method: Method,
  next: fn() -> Response,
) -> Response {
  case request.method == method {
    True -> next()
    False -> method_not_allowed([method])
  }
}

// TODO: test
// TODO: document
pub const path_segments = request.path_segments

// TODO: test
/// This function overrides an incoming POST request with a method given in
/// the request's `_method` query paramerter. This is useful as web browsers
/// typically only support GET and POST requests, but our application may
/// expect other HTTP methods that are more semantically correct.
///
/// The methods PUT, PATCH, and DELETE are accepted for overriding, all others
/// are ignored.
///
/// The `_method` query paramerter can be specified in a HTML form like so:
///
///    <form method="POST" action="/item/1?_method=DELETE">
///      <button type="submit">Delete item</button>
///    </form>
///
pub fn method_override(request: HttpRequest(a)) -> HttpRequest(a) {
  use <- bool.guard(when: request.method != http.Post, return: request)
  {
    use query <- result.try(request.get_query(request))
    use pair <- result.try(list.key_pop(query, "_method"))
    use method <- result.map(http.parse_method(pair.0))

    case method {
      http.Put | http.Patch | http.Delete -> request.set_method(request, method)
      _ -> request
    }
  }
  |> result.unwrap(request)
}

// TODO: test
// TODO: document
pub fn require_string_body(
  request: Request,
  next: fn(String) -> Response,
) -> Response {
  case read_entire_body(request) {
    Ok(body) -> require(bit_string.to_string(body), next)
    Error(_) -> entity_too_large()
  }
}

// TODO: test
// TODO: public?
// TODO: document
// TODO: note you probably want a `require_` function
// TODO: note it'll hang if you call it twice
// TODO: note it respects the max body size
fn read_entire_body(request: Request) -> Result(BitString, Nil) {
  let connection = request.body
  read_body_loop(
    connection.reader,
    connection.read_chunk_size,
    connection.max_body_size,
    <<>>,
  )
}

fn read_body_loop(
  reader: Reader,
  read_chunk_size: Int,
  max_body_size: Int,
  accumulator: BitString,
) -> Result(BitString, Nil) {
  use chunk <- result.try(reader(read_chunk_size))
  case chunk {
    ReadingFinished -> Ok(accumulator)
    Chunk(chunk, next) -> {
      let accumulator = bit_string.append(accumulator, chunk)
      case bit_string.byte_size(accumulator) > max_body_size {
        True -> Error(Nil)
        False ->
          read_body_loop(next, read_chunk_size, max_body_size, accumulator)
      }
    }
  }
}

// TODO: replace with a function that also supports multipart forms
// TODO: test
// TODO: document
pub fn require_form_urlencoded_body(
  request: Request,
  next: fn(List(#(String, String))) -> Response,
) -> Response {
  use body <- require_string_body(request)
  require(uri.parse_query(body), next)
}

// TODO: test
// TODO: document
pub fn require(
  result: Result(value, error),
  next: fn(value) -> Response,
) -> Response {
  case result {
    Ok(value) -> next(value)
    Error(_) -> bad_request()
  }
}

//
// Middleware
//

// TODO: test
// TODO: document
pub fn rescue_crashes(service: fn() -> Response) -> Response {
  case erlang.rescue(service) {
    Ok(response) -> response
    Error(error) -> {
      // TODO: log the error
      io.debug(error)
      internal_server_error()
    }
  }
}

// TODO: test
// TODO: document
// TODO: real implementation that uses the logger
pub fn log_requests(req: Request, service: fn() -> Response) -> Response {
  let response = service()
  [
    int.to_string(response.status),
    " ",
    string.uppercase(http.method_to_string(req.method)),
    " ",
    req.path,
  ]
  |> string.concat
  |> io.println
  response
}

//
// Testing
//

// TODO: test
// TODO: document
pub fn test_connection(body: BitString) -> Connection {
  make_connection(fn(_size) {
    Ok(Chunk(body, fn(_size) { Ok(ReadingFinished) }))
  })
}
