/// Wisp! A Gleam web framework.
///
/// ## Overview
///
/// Wisp is based around two concepts: handlers and middleware.
///
/// ### Handlers
///
/// A handler is a function that takes a HTTP request and returns a HTTP
/// response. A handler may also take other arguments, such as a "context" type
/// defined in your application which may hold other state such as a database
/// connection or user session.
///
/// ```gleam
/// import wisp.{Request, Response}
///
/// pub type Context {
///   Context(secret: String)
/// }
///
/// pub fn handle_request(request: Request, context: Context) -> Response {
///   wisp.ok()
/// }
/// ```
///
/// ### Middleware
///
/// A middleware is a function that takes a response returning function as its
/// last argument, and itself returns a response. As with handlers both
/// middleware and the functions they take as an argument may take other
/// arguments.
///
/// Middleware can be applied in a handler with Gleam's `use` syntax. Here the
/// `log_request` middleware is used to log a message for each HTTP request
/// handled, and the `serve_static` middleware is used to serve static files
/// such as images and CSS.
///
/// ```gleam
/// import wisp.{Request, Response}
///
/// pub fn handle_request(request: Request) -> Response {
///   use <- wisp.log_request
///   use <- wisp.serve_static(req, under: "/static", from: "/public")
///   wisp.ok()
/// }
/// ```
///
import gleam/string_builder.{StringBuilder}
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/erlang
import gleam/base
import gleam/bool
import gleam/crypto
import gleam/http.{Method}
import gleam/http/request.{Request as HttpRequest}
import gleam/http/response.{Response as HttpResponse}
import gleam/list
import gleam/result
import gleam/string
import gleam/option.{Option}
import gleam/uri
import gleam/io
import gleam/int
import simplifile
import mist

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
///   let assert Ok(_) =
///     wisp.mist_service(handle_request)
///     |> mist.new
///     |> mist.port(8000)
///     |> mist.start_http
///   process.sleep_forever()
/// }
/// ```
pub fn mist_service(
  handler: fn(Request) -> Response,
) -> fn(HttpRequest(mist.Connection)) -> HttpResponse(mist.ResponseData) {
  fn(request: HttpRequest(_)) {
    let connection = make_connection(mist_body_reader(request))
    let request = request.set_body(request, connection)
    let response =
      request
      |> handler
      |> mist_response

    // TODO: use some FFI to ensure this always happens, even if there is a crash
    let assert Ok(_) = delete_temporary_files(request)

    response
  }
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
    File(path) -> mist_send_file(path)
  }
  response
  |> response.set_body(body)
}

fn mist_send_file(path: String) -> mist.ResponseData {
  case mist.send_file(path, offset: 0, limit: option.None) {
    Ok(body) -> body
    Error(error) -> {
      // TODO: log error
      io.println("ERROR: " <> string.inspect(error))
      // TODO: return 500
      mist.Bytes(bit_builder.new())
    }
  }
}

//
// Responses
//

/// The body of a HTTP response, to be sent to the client.
///
pub type Body {
  /// A body of unicode text.
  ///
  /// The body is represented using a `StringBuilder`. If you have a `String`
  /// you can use the `string_builder.from_string` function to convert it.
  ///
  Text(StringBuilder)
  /// A body of the contents of a file.
  ///
  /// This will be sent efficiently using the `send_file` function of the
  /// underlying HTTP server. The file will not be read into memory so it is
  /// safe to send large files this way.
  ///
  File(path: String)
  /// An empty body. This may be returned by the `require_*` middleware
  /// functions in the event of a failure, invalid request, or other situation
  /// in which the request cannot be processed.
  ///
  /// Your application may wish to use a middleware to provide default responses
  /// in place of any with an empty body.
  ///
  Empty
}

/// An alias for a HTTP response containing a `Body`.
pub type Response =
  HttpResponse(Body)

/// Create an empty response with the given status code.
/// 
/// # Examples
/// 
/// ```gleam
/// response(200)
/// // -> Response(200, [], Empty)
/// ```
/// 
pub fn response(status: Int) -> Response {
  HttpResponse(status, [], Empty)
}

/// Set the body of a response.
/// 
/// # Examples
/// 
/// ```gleam
/// response(200)
/// |> set_body(File("/tmp/myfile.txt"))
/// // -> Response(200, [], File("/tmp/myfile.txt"))
/// ```
/// 
pub fn set_body(response: Response, body: Body) -> Response {
  response
  |> response.set_body(body)
}

/// Create a HTML response.
/// 
/// The body is expected to be valid HTML, though this is not validated.
/// The `content-type` header will be set to `text/html`.
/// 
/// # Examples
/// 
/// ```gleam
/// let body = string_builder.from_string("<h1>Hello, Joe!</h1>")
/// html_response(body, 200)
/// // -> Response(200, [#("content-type", "text/html")], Text(body))
/// ```
/// 
pub fn html_response(html: StringBuilder, status: Int) -> Response {
  HttpResponse(status, [#("content-type", "text/html")], Text(html))
}

/// Set the body of a response to a given HTML document, and set the
/// `content-type` header to `text/html`.
/// 
/// The body is expected to be valid HTML, though this is not validated.
/// 
/// # Examples
/// 
/// ```gleam
/// let body = string_builder.from_string("<h1>Hello, Joe!</h1>")
/// response(201)
/// |> html_body(body)
/// // -> Response(201, [#("content-type", "text/html")], Text(body))
/// ```
/// 
pub fn html_body(response: Response, html: StringBuilder) -> Response {
  response
  |> response.set_body(Text(html))
  |> response.set_header("content-type", "text/html")
}

/// Create an empty response with status code 405: Method Not Allowed. Use this
/// when a request does not have an appropriate method to be handled.
///
/// The `allow` header will be set to a comma separated list of the permitted
/// methods.
///
/// # Examples
///
/// ```gleam
/// method_not_allowed([Get, Post])
/// // -> Response(405, [#("allow", "GET, POST")], Empty)
/// ```
///
pub fn method_not_allowed(permitted: List(Method)) -> Response {
  let allowed =
    permitted
    |> list.map(http.method_to_string)
    |> list.sort(string.compare)
    |> string.join(", ")
    |> string.uppercase
  HttpResponse(405, [#("allow", allowed)], Empty)
}

/// Create an empty response with status code 200: OK.
///
/// # Examples
///
/// ```gleam
/// ok()
/// // -> Response(200, [], Empty)
/// ```
///
pub fn ok() -> Response {
  HttpResponse(200, [], Empty)
}

/// Create an empty response with status code 201: Created.
///
/// # Examples
///
/// ```gleam
/// created()
/// // -> Response(201, [], Empty)
/// ```
///
pub fn created() -> Response {
  HttpResponse(201, [], Empty)
}

/// Create an empty response with status code 202: Accepted.
///
/// # Examples
///
/// ```gleam
/// created()
/// // -> Response(202, [], Empty)
/// ```
///
pub fn accepted() -> Response {
  HttpResponse(202, [], Empty)
}

/// Create an empty response with status code 204: No content.
///
/// # Examples
///
/// ```gleam
/// no_content()
/// // -> Response(204, [], Empty)
/// ```
///
pub fn no_content() -> Response {
  HttpResponse(204, [], Empty)
}

/// Create an empty response with status code 404: No content.
///
/// # Examples
///
/// ```gleam
/// not_found()
/// // -> Response(404, [], Empty)
/// ```
///
pub fn not_found() -> Response {
  HttpResponse(404, [], Empty)
}

/// Create an empty response with status code 400: Bad request.
///
/// # Examples
///
/// ```gleam
/// bad_request()
/// // -> Response(400, [], Empty)
/// ```
///
pub fn bad_request() -> Response {
  HttpResponse(400, [], Empty)
}

/// Create an empty response with status code 413: Entity too large.
///
/// # Examples
///
/// ```gleam
/// entity_too_large()
/// // -> Response(413, [], Empty)
/// ```
///
pub fn entity_too_large() -> Response {
  HttpResponse(413, [], Empty)
}

/// Create an empty response with status code 500: Internal server error.
///
/// # Examples
///
/// ```gleam
/// internal_server_error()
/// // -> Response(500, [], Empty)
/// ```
///
pub fn internal_server_error() -> Response {
  HttpResponse(500, [], Empty)
}

//
// Requests
//

/// The connection to the client for a HTTP request.
/// 
/// The body of the request can be read from this connection using functions
/// such as `require_multipart_body`.
/// 
pub opaque type Connection {
  Connection(
    reader: Reader,
    // TODO: document these. Cannot be here as this is opaque.
    max_body_size: Int,
    max_files_size: Int,
    read_chunk_size: Int,
    temporary_directory: String,
  )
}

fn make_connection(body_reader: Reader) -> Connection {
  // TODO: replace `/tmp` with appropriate for the OS
  let prefix = "/tmp/gleam-wisp/"
  let temporary_directory = join_path(prefix, random_slug())
  Connection(
    reader: body_reader,
    max_body_size: 8_000_000,
    max_files_size: 32_000_000,
    read_chunk_size: 1_000_000,
    temporary_directory: temporary_directory,
  )
}

type BufferedReader {
  BufferedReader(reader: Reader, buffer: BitString)
}

type Quotas {
  Quotas(body: Int, files: Int)
}

fn decrement_body_quota(quotas: Quotas, size: Int) -> Result(Quotas, Response) {
  let quotas = Quotas(..quotas, body: quotas.body - size)
  case quotas.body < 0 {
    True -> Error(entity_too_large())
    False -> Ok(quotas)
  }
}

fn decrement_quota(quota: Int, size: Int) -> Result(Int, Response) {
  case quota - size {
    quota if quota < 0 -> Error(entity_too_large())
    quota -> Ok(quota)
  }
}

fn buffered_read(reader: BufferedReader, chunk_size: Int) -> Result(Read, Nil) {
  case reader.buffer {
    <<>> -> reader.reader(chunk_size)
    _ -> Ok(Chunk(reader.buffer, reader.reader))
  }
}

type Reader =
  fn(Int) -> Result(Read, Nil)

type Read {
  Chunk(BitString, next: Reader)
  ReadingFinished
}

/// Set the maximum permitted size of a request body of the request in bytes.
///
/// If a body is larger than this size attempting to read the body will result
/// in a response with status code 413: Entity too large will be returned to the
/// client.
///
/// This limit only applies for headers and bodies that get read into memory.
/// Part of a multipart body that contain files and so are streamed to disc
/// instead use the `max_files_size` limit.
///
pub fn set_max_body_size(request: Request, size: Int) -> Request {
  Connection(..request.body, max_body_size: size)
  |> request.set_body(request, _)
}

/// Get the maximum permitted size of a request body of the request in bytes.
/// 
pub fn get_max_body_size(request: Request) -> Int {
  request.body.max_body_size
}

/// Set the maximum permitted size of all files uploaded by a request, in bytes.
///
/// If a request contains fails which are larger in total than this size
/// then attempting to read the body will result in a response with status code
/// 413: Entity too large will be returned to the client.
///
/// This limit only applies for files in a multipart body that get streamed to
/// disc. For headers and other content that gets read into memory use the
/// `max_files_size` limit.
///
pub fn set_max_files_size(request: Request, size: Int) -> Request {
  Connection(..request.body, max_files_size: size)
  |> request.set_body(request, _)
}

/// Get the maximum permitted total size of a files uploaded by a request in
/// bytes.
/// 
pub fn get_max_files_size(request: Request) -> Int {
  request.body.max_files_size
}

/// The the size limit for each chunk of the request body when read from the
/// client.
///
/// This value is passed to the underlying web server when reading the body and
/// the exact size of chunks read depends on the server implementation. It most
/// likely will read chunks smaller than this size if not yet enough data has
/// been received from the client.
///
pub fn set_read_chunk_size(request: Request, size: Int) -> Request {
  Connection(..request.body, read_chunk_size: size)
  |> request.set_body(request, _)
}

/// Get the size limit for each chunk of the request body when read from the
/// client.
/// 
pub fn get_read_chunk_size(request: Request) -> Int {
  request.body.read_chunk_size
}

/// A convenient alias for a HTTP request with a Wisp connection as the body.
/// 
pub type Request =
  HttpRequest(Connection)

/// This middleware function ensures that the request has a specific HTTP
/// method, returning an empty response with status code 405: Method not allowed
/// if the method is not correct.
///
/// # Examples
/// 
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use <- wisp.require_method(request, http.Patch)
///   // ...
/// }
/// ```
///
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

// TODO: re-export once Gleam has a syntax for that
/// Return the non-empty segments of a request path.
/// 
/// # Examples
///
/// ```gleam
/// > request.new()
/// > |> request.set_path("/one/two/three")
/// > |> wisp.path_segments
/// ["one", "two", "three"]
/// ```
///
pub const path_segments = request.path_segments

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
/// # Examples
///
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   let request = wisp.method_override(request)
///   // The method has now been overridden if appropriate
/// }
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

// TODO: don't always return entity to large. Other errors are possible, such as
// network errors.
// TODO: document
// TODO: note you probably want a `require_` function
// TODO: note it'll hang if you call it twice
// TODO: note it respects the max body size
/// A middleware function which reads the entire body of the request as a string.
/// 
/// If the body is larger than the `max_body_size` limit then an empty response
/// with status code 413: Entity too large will be returned to the client.
/// 
/// If the body is found not to be valid UTF-8 then an empty response with
/// status code 400: Bad request will be returned to the client.
/// 
/// # Examples
///
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use body <- wisp.require_string_body(request)
///   // ...
/// }
/// ```
///
pub fn require_string_body(
  request: Request,
  next: fn(String) -> Response,
) -> Response {
  case read_entire_body(request) {
    Ok(body) -> require(bit_string.to_string(body), next)
    Error(_) -> entity_too_large()
  }
}

// Should we make this public?
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

// TODO: make private and replace with a generic require_form function
// TODO: test
// TODO: document
pub fn require_form_urlencoded_body(
  request: Request,
  next: fn(FormData) -> Response,
) -> Response {
  use body <- require_string_body(request)
  use pairs <- require(uri.parse_query(body))
  let pairs = sort_keys(pairs)
  next(FormData(values: pairs, files: []))
}

// TODO: make private and replace with a generic require_form function
// TODO: test
// TODO: document
pub fn require_multipart_body(
  request: Request,
  boundary: String,
  next: fn(FormData) -> Response,
) -> Response {
  let quotas =
    Quotas(files: request.body.max_files_size, body: request.body.max_body_size)
  let reader = BufferedReader(request.body.reader, <<>>)

  let result =
    read_multipart(request, reader, boundary, quotas, FormData([], []))
  case result {
    Ok(form_data) -> next(form_data)
    Error(response) -> response
  }
}

fn read_multipart(
  request: Request,
  reader: BufferedReader,
  boundary: String,
  quotas: Quotas,
  data: FormData,
) -> Result(FormData, Response) {
  let read_size = request.body.read_chunk_size

  // First we read the headers of the multipart part.
  let header_parser =
    fn_with_bad_request_error(http.parse_multipart_headers(_, boundary))
  let result = multipart_headers(reader, header_parser, read_size, quotas)
  use #(headers, reader, quotas) <- result.try(result)
  use #(name, filename) <- result.try(multipart_content_disposition(headers))

  // Then we read the body of the part.
  let parse = fn_with_bad_request_error(http.parse_multipart_body(_, boundary))
  use #(data, reader, quotas) <- result.try(case filename {
    // There is a file name, so we treat this as a file upload, streaming the
    // contents to a temporary file and using the dedicated files size quota.
    option.Some(file_name) -> {
      use path <- result.try(or_500(new_temporary_file(request)))
      let append = multipart_file_append
      let q = quotas.files
      let result =
        multipart_body(reader, parse, boundary, read_size, q, append, path)
      use #(reader, quota, _) <- result.map(result)
      let quotas = Quotas(..quotas, files: quota)
      let file = UploadedFile(path: path, file_name: file_name)
      let data = FormData(..data, files: [#(name, file), ..data.files])
      #(data, reader, quotas)
    }

    // No file name, this is a regular form value that we hold in memory.
    option.None -> {
      let append = fn(data, chunk) { Ok(bit_string.append(data, chunk)) }
      let q = quotas.body
      let result =
        multipart_body(reader, parse, boundary, read_size, q, append, <<>>)
      use #(reader, quota, value) <- result.try(result)
      let quotas = Quotas(..quotas, body: quota)
      use value <- result.map(bit_string_to_string(value))
      let data = FormData(..data, values: [#(name, value), ..data.values])
      #(data, reader, quotas)
    }
  })

  case reader {
    // There's at least one more part, read it.
    option.Some(reader) ->
      read_multipart(request, reader, boundary, quotas, data)
    // There are no more parts, we're done.
    option.None -> Ok(FormData(sort_keys(data.values), sort_keys(data.files)))
  }
}

fn bit_string_to_string(bits: BitString) -> Result(String, Response) {
  bit_string.to_string(bits)
  |> result.replace_error(bad_request())
}

fn multipart_file_append(
  path: String,
  chunk: BitString,
) -> Result(String, Response) {
  chunk
  |> simplifile.append_bits(path)
  |> or_500
  |> result.replace(path)
}

fn or_500(result: Result(a, b)) -> Result(a, Response) {
  case result {
    Ok(value) -> Ok(value)
    Error(error) -> {
      // TODO: log error
      io.println("ERROR: " <> string.inspect(error))
      Error(internal_server_error())
    }
  }
}

fn multipart_body(
  reader: BufferedReader,
  parse: fn(BitString) -> Result(http.MultipartBody, Response),
  boundary: String,
  chunk_size: Int,
  quota: Int,
  append: fn(t, BitString) -> Result(t, Response),
  data: t,
) -> Result(#(Option(BufferedReader), Int, t), Response) {
  use #(chunk, reader) <- result.try(read_chunk(reader, chunk_size))
  use output <- result.try(parse(chunk))

  case output {
    http.MultipartBody(chunk, done, remaining) -> {
      let used = bit_string.byte_size(chunk) - bit_string.byte_size(remaining)
      use quotas <- result.try(decrement_quota(quota, used))
      let reader = BufferedReader(reader, remaining)
      let reader = case done {
        True -> option.None
        False -> option.Some(reader)
      }
      use value <- result.map(append(data, chunk))
      #(reader, quotas, value)
    }

    http.MoreRequiredForBody(chunk, parse) -> {
      let parse = fn_with_bad_request_error(parse(_))
      let reader = BufferedReader(reader, <<>>)
      use data <- result.try(append(data, chunk))
      multipart_body(reader, parse, boundary, chunk_size, quota, append, data)
    }
  }
}

fn fn_with_bad_request_error(
  f: fn(a) -> Result(b, c),
) -> fn(a) -> Result(b, Response) {
  fn(a) {
    f(a)
    |> result.replace_error(bad_request())
  }
}

fn multipart_content_disposition(
  headers: List(http.Header),
) -> Result(#(String, Option(String)), Response) {
  {
    use header <- result.try(list.key_find(headers, "content-disposition"))
    use header <- result.try(http.parse_content_disposition(header))
    use name <- result.map(list.key_find(header.parameters, "name"))
    let filename =
      option.from_result(list.key_find(header.parameters, "filename"))
    #(name, filename)
  }
  |> result.replace_error(bad_request())
}

fn read_chunk(
  reader: BufferedReader,
  chunk_size: Int,
) -> Result(#(BitString, Reader), Response) {
  buffered_read(reader, chunk_size)
  |> result.replace_error(bad_request())
  |> result.try(fn(chunk) {
    case chunk {
      Chunk(chunk, next) -> Ok(#(chunk, next))
      ReadingFinished -> Error(bad_request())
    }
  })
}

fn multipart_headers(
  reader: BufferedReader,
  parse: fn(BitString) -> Result(http.MultipartHeaders, Response),
  chunk_size: Int,
  quotas: Quotas,
) -> Result(#(List(http.Header), BufferedReader, Quotas), Response) {
  use #(chunk, reader) <- result.try(read_chunk(reader, chunk_size))
  use headers <- result.try(parse(chunk))

  case headers {
    http.MultipartHeaders(headers, remaining) -> {
      let used = bit_string.byte_size(chunk) - bit_string.byte_size(remaining)
      use quotas <- result.map(decrement_body_quota(quotas, used))
      let reader = BufferedReader(reader, remaining)
      #(headers, reader, quotas)
    }
    http.MoreRequiredForHeaders(parse) -> {
      let parse = fn(chunk) {
        parse(chunk)
        |> result.replace_error(bad_request())
      }
      let reader = BufferedReader(reader, <<>>)
      multipart_headers(reader, parse, chunk_size, quotas)
    }
  }
}

fn sort_keys(pairs: List(#(String, t))) -> List(#(String, t)) {
  list.sort(pairs, fn(a, b) { string.compare(a.0, b.0) })
}

// TODO: determine is this a good API. Perhaps the response should be
// parameterised?
/// A middleware function which returns an empty response with the status code
/// 400: Bad request if the result is an error.
/// 
/// This function is similar to the `try` function of the `gleam/result` module,
/// except returning a HTTP response rather than the error when the result is
/// not OK.
/// 
/// # Example
/// 
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use value <- wisp.request(result_returning_function())
///   // ...
/// }
/// ```
/// 
pub fn require(
  result: Result(value, error),
  next: fn(value) -> Response,
) -> Response {
  case result {
    Ok(value) -> next(value)
    Error(_) -> bad_request()
  }
}

/// Data parsed from form sent in a request's body.
/// 
pub type FormData {
  FormData(
    /// String values of the form's fields.
    values: List(#(String, String)),
    /// Uploaded files.
    files: List(#(String, UploadedFile)),
  )
}

pub type UploadedFile {
  UploadedFile(
    /// The name that was given to the file in the form.
    /// This is user input and should not be trusted.
    file_name: String,
    /// The location of the file on the server.
    /// This is a temporary file and will be deleted when the request has
    /// finished being handled.
    path: String,
  )
}

//
// MIME types
//

// TODO: move to another package
fn extension_to_mime_type(extension: String) -> String {
  case extension {
    "7z" -> "application/x-7z-compressed"
    "aac" -> "audio/aac"
    "abw" -> "application/x-abiword"
    "ai" -> "application/postscript"
    "arc" -> "application/x-freearc"
    "asice" -> "application/vnd.etsi.asic-e+zip"
    "asics" -> "application/vnd.etsi.asic-s+zip"
    "atom" -> "application/atom+xml"
    "avi" -> "video/x-msvideo"
    "avif" -> "image/avif"
    "azw" -> "application/vnd.amazon.ebook"
    "bin" -> "application/octet-stream"
    "bmp" -> "image/bmp"
    "bz" -> "application/x-bzip"
    "bz2" -> "application/x-bzip2"
    "cda" -> "application/x-cdf"
    "csh" -> "application/x-csh"
    "css" -> "text/css"
    "csv" -> "text/csv"
    "doc" -> "application/msword"
    "docx" ->
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "eot" -> "application/vnd.ms-fontobject"
    "eps" -> "application/postscript"
    "epub" -> "application/epub+zip"
    "gif" -> "image/gif"
    "gz" -> "application/gzip"
    "heic" -> "image/heic"
    "heif" -> "image/heif"
    "htm" -> "text/html"
    "html" -> "text/html"
    "ico" -> "image/vnd.microsoft.icon"
    "ics" -> "text/calendar"
    "jar" -> "application/java-archive"
    "jpeg" -> "image/jpeg"
    "jpg" -> "image/jpeg"
    "js" -> "text/javascript"
    "json" -> "application/json"
    "json-api" -> "application/vnd.api+json"
    "json-patch" -> "application/json-patch+json"
    "jsonld" -> "application/ld+json"
    "jxl" -> "image/jxl"
    "markdown" -> "text/markdown"
    "md" -> "text/markdown"
    "mdb" -> "application/x-msaccess"
    "mid" -> "audio/midi"
    "midi" -> "audio/midi"
    "mjs" -> "text/javascript"
    "mov" -> "video/quicktime"
    "mp3" -> "audio/mpeg"
    "mp4" -> "video/mp4"
    "mpeg" -> "video/mpeg"
    "mpg" -> "video/mpeg"
    "mpkg" -> "application/vnd.apple.installer+xml"
    "odp" -> "application/vnd.oasis.opendocument.presentation"
    "ods" -> "application/vnd.oasis.opendocument.spreadsheet"
    "odt" -> "application/vnd.oasis.opendocument.text"
    "oga" -> "audio/ogg"
    "ogv" -> "video/ogg"
    "ogx" -> "application/ogg"
    "opus" -> "audio/opus"
    "otf" -> "font/otf"
    "pdf" -> "application/pdf"
    "php" -> "application/x-httpd-php"
    "png" -> "image/png"
    "ppt" -> "application/vnd.ms-powerpoint"
    "pptx" ->
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    "ps" -> "application/postscript"
    "psd" -> "image/vnd.adobe.photoshop"
    "rar" -> "application/vnd.rar"
    "rss" -> "application/rss+xml"
    "rtf" -> "application/rtf"
    "sce" -> "application/vnd.etsi.asic-e+zip"
    "scs" -> "application/vnd.etsi.asic-s+zip"
    "sh" -> "application/x-sh"
    "svg" -> "image/svg+xml"
    "svgz" -> "image/svg+xml"
    "swf" -> "application/x-shockwave-flash"
    "tar" -> "application/x-tar"
    "text" -> "text/plain"
    "tif" -> "image/tiff"
    "tiff" -> "image/tiff"
    "ts" -> "video/mp2t"
    "ttf" -> "font/ttf"
    "txt" -> "text/plain"
    "vsd" -> "application/vnd.visio"
    "wasm" -> "application/wasm"
    "wav" -> "audio/wav"
    "weba" -> "audio/webm"
    "webm" -> "video/webm"
    "webmanifest" -> "application/manifest+json"
    "webp" -> "image/webp"
    "wmv" -> "video/x-ms-wmv"
    "woff" -> "font/woff"
    "woff2" -> "font/woff2"
    "xhtml" -> "application/xhtml+xml"
    "xls" -> "application/vnd.ms-excel"
    "xlsx" ->
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    "xml" -> "application/xml"
    "xul" -> "application/vnd.mozilla.xul+xml"
    "zip" -> "application/zip"
    _ -> "application/octet-stream"
  }
}

//
// Middleware
//

/// A middleware function that rescues crashes and returns an empty response
/// with status code 500: Internal server error.
///
/// # Examples
///
/// ```gleam
/// fn handle_request(req: Request) -> Response {
///   use <- wisp.rescue_crashes
///   // ...
/// }
/// ```
///
pub fn rescue_crashes(handler: fn() -> Response) -> Response {
  case erlang.rescue(handler) {
    Ok(response) -> response
    Error(error) -> {
      // TODO: log the error
      io.println("ERROR: " <> string.inspect(error))
      internal_server_error()
    }
  }
}

// TODO: test, somehow.
/// A middleware function that logs details about the request and response.
///
/// The format used logged by this middleware may change in future versions of
/// Wisp.
///
/// # Examples
///
/// ```gleam
/// fn handle_request(req: Request) -> Response {
///   use <- wisp.log_request(req)
///   // ...
/// }
/// ```
///
pub fn log_request(req: Request, handler: fn() -> Response) -> Response {
  let response = handler()
  [
    int.to_string(response.status),
    " ",
    string.uppercase(http.method_to_string(req.method)),
    " ",
    req.path,
  ]
  |> string.concat
  // TODO: use the logger
  |> io.println
  response
}

fn remove_preceeding_slashes(string: String) -> String {
  case string {
    "/" <> rest -> remove_preceeding_slashes(rest)
    _ -> string
  }
}

// TODO: replace with simplifile function when it exists
fn join_path(a: String, b: String) -> String {
  let b = remove_preceeding_slashes(b)
  case string.ends_with(a, "/") {
    True -> a <> b
    False -> a <> "/" <> b
  }
}

/// A middleware function that serves files from a directory, along with a
/// suitable `content-type` header for known file extensions.
///
/// Files are sent using the `File` response body type, so they will be sent
/// directly to the client from the disc, without being read into memory.
///
/// The `under` parameter is the request path prefix that must match for the
/// file to be served.
/// 
/// | `under`   | `from`  | `request.path`     | `file`                  |
/// |-----------|---------|--------------------|-------------------------|
/// | `/static` | `/data` | `/static/file.txt` | `/data/file.txt`        |
/// | ``        | `/data` | `/static/file.txt` | `/data/static/file.txt` |
/// | `/static` | ``      | `/static/file.txt` | `file.txt`              |
///
/// This middleware will discard any `..` path segments in the request path to
/// prevent the client from accessing files outside of the directory. It is
/// advised not to serve a directory that contains your source code, application
/// configuration, database, or other private files.
///
/// # Examples
///
/// ```gleam
/// fn handle_request(req: Request) -> Response {
///   use <- wisp.serve_static(req, under: "/static", from: "/public")
///   // ...
/// }
/// ```
///
pub fn serve_static(
  req: Request,
  under prefix: String,
  from directory: String,
  next handler: fn() -> Response,
) -> Response {
  let path = remove_preceeding_slashes(req.path)
  let prefix = remove_preceeding_slashes(prefix)
  case req.method, string.starts_with(path, prefix) {
    http.Get, True -> {
      let path =
        path
        |> string.drop_left(string.length(prefix))
        |> string.replace(each: "..", with: "")
        |> join_path(directory, _)

      let mime_type =
        req.path
        |> string.split(on: ".")
        |> list.last
        |> result.unwrap("")
        |> extension_to_mime_type

      case simplifile.is_file(path) {
        False -> handler()
        True ->
          response.new(200)
          |> response.set_header("content-type", mime_type)
          |> response.set_body(File(path))
      }
    }
    _, _ -> handler()
  }
}

//
// File uploads
//

/// Create a new temporary directory for the given request.
///
/// If you are using the `mist_service` function or another compliant web server
/// adapter then this file will be deleted for you when the request is complete.
/// Otherwise you will need to call the `delete_temporary_files` function
/// yourself.
///
pub fn new_temporary_file(
  request: Request,
) -> Result(String, simplifile.FileError) {
  let directory = request.body.temporary_directory
  use _ <- result.try(simplifile.create_directory_all(directory))
  let path = join_path(directory, random_slug())
  use _ <- result.map(simplifile.create_file(path))
  path
}

/// Delete any temporary files created for the given request.
///
/// If you are using the `mist_service` function or another compliant web server
/// adapter then this file will be deleted for you when the request is complete.
/// Otherwise you will need to call this function yourself.
///
pub fn delete_temporary_files(
  request: Request,
) -> Result(Nil, simplifile.FileError) {
  case simplifile.delete(request.body.temporary_directory) {
    Error(simplifile.Enoent) -> Ok(Nil)
    other -> other
  }
}

//
// Cryptography
//

fn random_slug() -> String {
  crypto.strong_random_bytes(16)
  |> base.url_encode64(False)
}

//
// Testing
//

// TODO: test
// TODO: document
// TODO: chunk the body
pub fn test_connection(body: BitString) -> Connection {
  make_connection(fn(_size) {
    Ok(Chunk(body, fn(_size) { Ok(ReadingFinished) }))
  })
}

// TODO: better API
// TODO: test
// TODO: document
pub fn test_request(body: BitString) -> Request {
  request.new()
  |> request.set_body(test_connection(body))
}

// TODO: test
// TODO: document
pub fn body_to_string_builder(body: Body) -> StringBuilder {
  case body {
    Empty -> string_builder.new()
    Text(text) -> text
    File(path) -> {
      let assert Ok(contents) = simplifile.read(path)
      string_builder.from_string(contents)
    }
  }
}

// TODO: test
// TODO: document
pub fn body_to_bit_builder(body: Body) -> BitBuilder {
  case body {
    Empty -> bit_builder.new()
    Text(text) -> bit_builder.from_string_builder(text)
    File(path) -> {
      let assert Ok(contents) = simplifile.read_bits(path)
      bit_builder.from_bit_string(contents)
    }
  }
}
