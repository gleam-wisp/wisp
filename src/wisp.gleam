import exception
import gleam/bit_array
import gleam/bool
import gleam/bytes_builder.{type BytesBuilder}
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/erlang/atom.{type Atom}
import gleam/http.{type Method}
import gleam/http/cookie
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response.{
  type Response as HttpResponse, Response as HttpResponse,
}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import gleam/uri
import logging
import marceau
import simplifile
import wisp/internal

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
  /// A body of binary data.
  ///
  /// The body is represented using a `BytesBuilder`. If you have a `BitArray`
  /// you can use the `bytes_builder.from_bit_array` function to convert it.
  ///
  Bytes(BytesBuilder)
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

/// Send a file from the disc as a file download.
///
/// The operating system `send_file` function is used to efficiently send the
/// file over the network socket without reading the entire file into memory.
///
/// The `content-disposition` header will be set to `attachment;
/// filename="name"` to ensure the file is downloaded by the browser. This is
/// especially good for files that the browser would otherwise attempt to open
/// as this can result in cross-site scripting vulnerabilities.
///
/// If you wish to not set the `content-disposition` header you could use the
/// `set_body` function with the `File` body variant.
///
/// # Examples
///
/// ```gleam
/// response(200)
/// |> file_download(named: "myfile.txt", from: "/tmp/myfile.txt")
/// // -> Response(
/// //   200,
/// //   [#("content-disposition", "attachment; filename=\"myfile.txt\"")],
/// //   File("/tmp/myfile.txt"),
/// // )
/// ```
///
pub fn file_download(
  response: Response,
  named name: String,
  from path: String,
) -> Response {
  let name = uri.percent_encode(name)
  response
  |> response.set_header(
    "content-disposition",
    "attachment; filename=\"" <> name <> "\"",
  )
  |> response.set_body(File(path))
}

/// Send a file from memory as a file download.
///
/// If your file is already on the disc use `file_download` instead, to avoid
/// having to read the file into memory to send it.
///
/// The `content-disposition` header will be set to `attachment;
/// filename="name"` to ensure the file is downloaded by the browser. This is
/// especially good for files that the browser would otherwise attempt to open
/// as this can result in cross-site scripting vulnerabilities.
///
/// # Examples
///
/// ```gleam
/// response(200)
/// |> file_download_from_memory(named: "myfile.txt", containing: "Hello, Joe!")
/// // -> Response(
/// //   200,
/// //   [#("content-disposition", "attachment; filename=\"myfile.txt\"")],
/// //   File("/tmp/myfile.txt"),
/// // )
/// ```
///
pub fn file_download_from_memory(
  response: Response,
  named name: String,
  containing data: BytesBuilder,
) -> Response {
  let name = uri.percent_encode(name)
  response
  |> response.set_header(
    "content-disposition",
    "attachment; filename=\"" <> name <> "\"",
  )
  |> response.set_body(Bytes(data))
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
  HttpResponse(
    status,
    [#("content-type", "text/html; charset=utf-8")],
    Text(html),
  )
}

/// Create a JSON response.
///
/// The body is expected to be valid JSON, though this is not validated.
/// The `content-type` header will be set to `application/json`.
///
/// # Examples
///
/// ```gleam
/// let body = string_builder.from_string("{\"name\": \"Joe\"}")
/// json_response(body, 200)
/// // -> Response(200, [#("content-type", "application/json")], Text(body))
/// ```
///
pub fn json_response(json: StringBuilder, status: Int) -> Response {
  HttpResponse(
    status,
    [#("content-type", "application/json; charset=utf-8")],
    Text(json),
  )
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
/// // -> Response(201, [#("content-type", "text/html; charset=utf-8")], Text(body))
/// ```
///
pub fn html_body(response: Response, html: StringBuilder) -> Response {
  response
  |> response.set_body(Text(html))
  |> response.set_header("content-type", "text/html; charset=utf-8")
}

/// Set the body of a response to a given JSON document, and set the
/// `content-type` header to `application/json`.
///
/// The body is expected to be valid JSON, though this is not validated.
///
/// # Examples
///
/// ```gleam
/// let body = string_builder.from_string("{\"name\": \"Joe\"}")
/// response(201)
/// |> json_body(body)
/// // -> Response(201, [#("content-type", "application/json; charset=utf-8")], Text(body))
/// ```
///
pub fn json_body(response: Response, json: StringBuilder) -> Response {
  response
  |> response.set_body(Text(json))
  |> response.set_header("content-type", "application/json; charset=utf-8")
}

/// Set the body of a response to a given string builder.
///
/// You likely want to also set the request `content-type` header to an
/// appropriate value for the format of the content.
///
/// # Examples
///
/// ```gleam
/// let body = string_builder.from_string("Hello, Joe!")
/// response(201)
/// |> string_builder_body(body)
/// // -> Response(201, [], Text(body))
/// ```
///
pub fn string_builder_body(
  response: Response,
  content: StringBuilder,
) -> Response {
  response
  |> response.set_body(Text(content))
}

/// Set the body of a response to a given string builder.
///
/// You likely want to also set the request `content-type` header to an
/// appropriate value for the format of the content.
///
/// # Examples
///
/// ```gleam
/// let body =
/// response(201)
/// |> string_body("Hello, Joe!")
/// // -> Response(
/// //   201,
/// //   [],
/// //   Text(string_builder.from_string("Hello, Joe"))
/// // )
/// ```
///
pub fn string_body(response: Response, content: String) -> Response {
  response
  |> response.set_body(Text(string_builder.from_string(content)))
}

/// Escape a string so that it can be safely included in a HTML document.
///
/// Any content provided by the user should be escaped before being included in
/// a HTML document to prevent cross-site scripting attacks.
///
/// # Examples
///
/// ```gleam
/// escape_html("<h1>Hello, Joe!</h1>")
/// // -> "&lt;h1&gt;Hello, Joe!&lt;/h1&gt;"
/// ```
///
pub fn escape_html(content: String) -> String {
  let bits = <<content:utf8>>
  let acc = do_escape_html(bits, 0, bits, [])

  list.reverse(acc)
  |> bit_array.concat
  // We know the bit array produced by `do_escape_html` is still a valid utf8
  // string so we coerce it without passing through the validation steps of
  // `bit_array.to_string`.
  |> coerce_bit_array_to_string
}

@external(erlang, "wisp_ffi", "coerce")
fn coerce_bit_array_to_string(bit_array: BitArray) -> String

// A possible way to escape chars would be to split the string into graphemes,
// traverse those one by one and accumulate them back into a string escaping
// ">", "<", etc. as we see them.
//
// However, we can be a lot more performant by working directly on the
// `BitArray` representing a Gleam UTF-8 String.
// This means that, instead of popping a grapheme at a time, we can work
// directly on BitArray slices: this has the big advantage of making sure we
// share as much as possible with the original string without having to build
// a new one from scratch.
//
fn do_escape_html(
  bin: BitArray,
  skip: Int,
  original: BitArray,
  acc: List(BitArray),
) -> List(BitArray) {
  case bin {
    // If we find a char to escape we just advance the `skip` counter so that
    // it will be ignored in the following slice, then we append the escaped
    // version to the accumulator.
    <<"<":utf8, rest:bits>> -> {
      let acc = [<<"&lt;":utf8>>, ..acc]
      do_escape_html(rest, skip + 1, original, acc)
    }

    <<">":utf8, rest:bits>> -> {
      let acc = [<<"&gt;":utf8>>, ..acc]
      do_escape_html(rest, skip + 1, original, acc)
    }

    <<"&":utf8, rest:bits>> -> {
      let acc = [<<"&amp;":utf8>>, ..acc]
      do_escape_html(rest, skip + 1, original, acc)
    }

    // For any other bit that doesn't need to be escaped we go into an inner
    // loop, consuming as much "non-escapable" chars as possible.
    <<_char, rest:bits>> -> do_escape_html_regular(rest, skip, original, acc, 1)

    <<>> -> acc

    _ -> panic as "non byte aligned string, all strings should be byte aligned"
  }
}

fn do_escape_html_regular(
  bin: BitArray,
  skip: Int,
  original: BitArray,
  acc: List(BitArray),
  len: Int,
) -> List(BitArray) {
  // Remember, if we're here it means we've found a char that doesn't need to be
  // escaped, so what we want to do is advance the `len` counter until we reach
  // a char that _does_ need to be escaped and take the slice going from
  // `skip` with size `len`.
  //
  // Imagine we're escaping this string: "abc<def&ghi" and we've reached 'd':
  // ```
  //    abc<def&ghi
  //       ^ `skip` points here
  // ```
  // We're going to be increasing `len` until we reach the '&':
  // ```
  //    abc<def&ghi
  //        ^^^ len will be 3 when we reach the '&' that needs escaping
  // ```
  // So we take the slice corresponding to "def".
  //
  case bin {
    // If we reach a char that has to be escaped we append the slice starting
    // from `skip` with size `len` and the escaped char.
    // This is what allows us to share as much of the original string as
    // possible: we only allocate a new BitArray for the escaped chars,
    // everything else is just a slice of the original String.
    <<"<":utf8, rest:bits>> -> {
      let assert Ok(slice) = bit_array.slice(original, skip, len)
      let acc = [<<"&lt;":utf8>>, slice, ..acc]
      do_escape_html(rest, skip + len + 1, original, acc)
    }

    <<">":utf8, rest:bits>> -> {
      let assert Ok(slice) = bit_array.slice(original, skip, len)
      let acc = [<<"&gt;":utf8>>, slice, ..acc]
      do_escape_html(rest, skip + len + 1, original, acc)
    }

    <<"&":utf8, rest:bits>> -> {
      let assert Ok(slice) = bit_array.slice(original, skip, len)
      let acc = [<<"&amp;":utf8>>, slice, ..acc]
      do_escape_html(rest, skip + len + 1, original, acc)
    }

    // If a char doesn't need escaping we keep increasing the length of the
    // slice we're going to take.
    <<_char, rest:bits>> ->
      do_escape_html_regular(rest, skip, original, acc, len + 1)

    <<>> ->
      case skip {
        0 -> [original]
        _ -> {
          let assert Ok(slice) = bit_array.slice(original, skip, len)
          [slice, ..acc]
        }
      }

    _ -> panic as "non byte aligned string, all strings should be byte aligned"
  }
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
/// method_not_allowed(allowed: [Get, Post])
/// // -> Response(405, [#("allow", "GET, POST")], Empty)
/// ```
///
pub fn method_not_allowed(allowed methods: List(Method)) -> Response {
  let allowed =
    methods
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
/// accepted()
/// // -> Response(202, [], Empty)
/// ```
///
pub fn accepted() -> Response {
  HttpResponse(202, [], Empty)
}

/// Create an empty response with status code 303: See Other, and the `location`
/// header set to the given URL. Used to redirect the client to another page.
///
/// # Examples
///
/// ```gleam
/// redirect(to: "https://example.com")
/// // -> Response(303, [#("location", "https://example.com")], Empty)
/// ```
///
pub fn redirect(to url: String) -> Response {
  HttpResponse(303, [#("location", url)], Empty)
}

/// Create an empty response with status code 308: Moved Permanently, and the
/// `location` header set to the given URL. Used to redirect the client to
/// another page.
///
/// This redirect is permanent and the client is expected to cache the new
/// location, using it for future requests.
///
/// # Examples
///
/// ```gleam
/// moved_permanently(to: "https://example.com")
/// // -> Response(308, [#("location", "https://example.com")], Empty)
/// ```
///
pub fn moved_permanently(to url: String) -> Response {
  HttpResponse(308, [#("location", url)], Empty)
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

/// Create an empty response with status code 415: Unsupported media type.
///
/// The `allow` header will be set to a comma separated list of the permitted
/// content-types.
///
/// # Examples
///
/// ```gleam
/// unsupported_media_type(accept: ["application/json", "text/plain"])
/// // -> Response(415, [#("allow", "application/json, text/plain")], Empty)
/// ```
///
pub fn unsupported_media_type(accept acceptable: List(String)) -> Response {
  let acceptable = string.join(acceptable, ", ")
  HttpResponse(415, [#("accept", acceptable)], Empty)
}

/// Create an empty response with status code 422: Unprocessable entity.
///
/// # Examples
///
/// ```gleam
/// unprocessable_entity()
/// // -> Response(422, [], Empty)
/// ```
///
pub fn unprocessable_entity() -> Response {
  HttpResponse(422, [], Empty)
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
pub type Connection =
  internal.Connection

type BufferedReader {
  BufferedReader(reader: internal.Reader, buffer: BitArray)
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

fn buffered_read(
  reader: BufferedReader,
  chunk_size: Int,
) -> Result(internal.Read, Nil) {
  case reader.buffer {
    <<>> -> reader.reader(chunk_size)
    _ -> Ok(internal.Chunk(reader.buffer, reader.reader))
  }
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
  internal.Connection(..request.body, max_body_size: size)
  |> request.set_body(request, _)
}

/// Get the maximum permitted size of a request body of the request in bytes.
///
pub fn get_max_body_size(request: Request) -> Int {
  request.body.max_body_size
}

/// Set the secret key base used to sign cookies and other sensitive data.
///
/// This key must be at least 64 bytes long and should be kept secret. Anyone
/// with this secret will be able to manipulate signed cookies and other sensitive
/// data.
///
/// # Panics
///
/// This function will panic if the key is less than 64 bytes long.
///
pub fn set_secret_key_base(request: Request, key: String) -> Request {
  case string.byte_size(key) < 64 {
    True -> panic as "Secret key base must be at least 64 bytes long"
    False ->
      internal.Connection(..request.body, secret_key_base: key)
      |> request.set_body(request, _)
  }
}

/// Get the secret key base used to sign cookies and other sensitive data.
///
pub fn get_secret_key_base(request: Request) -> String {
  request.body.secret_key_base
}

/// Set the maximum permitted size of all files uploaded by a request, in bytes.
///
/// If a request contains fails which are larger in total than this size
/// then attempting to read the body will result in a response with status code
/// 413: Entity too large will be returned to the client.
///
/// This limit only applies for files in a multipart body that get streamed to
/// disc. For headers and other content that gets read into memory use the
/// `max_body_size` limit.
///
pub fn set_max_files_size(request: Request, size: Int) -> Request {
  internal.Connection(..request.body, max_files_size: size)
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
  internal.Connection(..request.body, read_chunk_size: size)
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
  HttpRequest(internal.Connection)

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
    False -> method_not_allowed(allowed: [method])
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

// TODO: re-export once Gleam has a syntax for that
/// Set a given header to a given value, replacing any existing value.
///
/// # Examples
///
/// ```gleam
/// > wisp.ok()
/// > |> wisp.set_header("content-type", "application/json")
/// Request(200, [#("content-type", "application/json")], Empty)
/// ```
///
pub const set_header = response.set_header

/// Parse the query parameters of a request into a list of key-value pairs. The
/// `key_find` function in the `gleam/list` stdlib module may be useful for
/// finding values in the list.
///
/// Query parameter names do not have to be unique and so may appear multiple
/// times in the list.
///
pub fn get_query(request: Request) -> List(#(String, String)) {
  request.get_query(request)
  |> result.unwrap([])
}

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
/// ```
///
pub fn method_override(request: HttpRequest(a)) -> HttpRequest(a) {
  use <- bool.guard(when: request.method != http.Post, return: request)
  {
    use query <- result.try(request.get_query(request))
    use value <- result.try(list.key_find(query, "_method"))
    use method <- result.map(http.parse_method(value))

    case method {
      http.Put | http.Patch | http.Delete -> request.set_method(request, method)
      _ -> request
    }
  }
  |> result.unwrap(request)
}

// TODO: don't always return entity too large. Other errors are possible, such as
// network errors.
/// A middleware function which reads the entire body of the request as a string.
///
/// This function does not cache the body in any way, so if you call this
/// function (or any other body reading function) more than once it may hang or
/// return an incorrect value, depending on the underlying web server. It is the
/// responsibility of the caller to cache the body if it is needed multiple
/// times.
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
  case read_body_to_bitstring(request) {
    Ok(body) -> or_400(bit_array.to_string(body), next)
    Error(_) -> entity_too_large()
  }
}

// TODO: don't always return entity too large. Other errors are possible, such as
// network errors.
/// A middleware function which reads the entire body of the request as a bit
/// string.
///
/// This function does not cache the body in any way, so if you call this
/// function (or any other body reading function) more than once it may hang or
/// return an incorrect value, depending on the underlying web server. It is the
/// responsibility of the caller to cache the body if it is needed multiple
/// times.
///
/// If the body is larger than the `max_body_size` limit then an empty response
/// with status code 413: Entity too large will be returned to the client.
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
pub fn require_bit_array_body(
  request: Request,
  next: fn(BitArray) -> Response,
) -> Response {
  case read_body_to_bitstring(request) {
    Ok(body) -> next(body)
    Error(_) -> entity_too_large()
  }
}

// TODO: don't always return entity to large. Other errors are possible, such as
// network errors.
/// Read the entire body of the request as a bit string.
///
/// You may instead wish to use the `require_bit_array_body` or the
/// `require_string_body` middleware functions instead.
///
/// This function does not cache the body in any way, so if you call this
/// function (or any other body reading function) more than once it may hang or
/// return an incorrect value, depending on the underlying web server. It is the
/// responsibility of the caller to cache the body if it is needed multiple
/// times.
///
/// If the body is larger than the `max_body_size` limit then an empty response
/// with status code 413: Entity too large will be returned to the client.
///
pub fn read_body_to_bitstring(request: Request) -> Result(BitArray, Nil) {
  let connection = request.body
  read_body_loop(
    connection.reader,
    connection.read_chunk_size,
    connection.max_body_size,
    <<>>,
  )
}

fn read_body_loop(
  reader: internal.Reader,
  read_chunk_size: Int,
  max_body_size: Int,
  accumulator: BitArray,
) -> Result(BitArray, Nil) {
  use chunk <- result.try(reader(read_chunk_size))
  case chunk {
    internal.ReadingFinished -> Ok(accumulator)
    internal.Chunk(chunk, next) -> {
      let accumulator = bit_array.append(accumulator, chunk)
      case bit_array.byte_size(accumulator) > max_body_size {
        True -> Error(Nil)
        False ->
          read_body_loop(next, read_chunk_size, max_body_size, accumulator)
      }
    }
  }
}

/// A middleware which extracts form data from the body of a request that is
/// encoded as either `application/x-www-form-urlencoded` or
/// `multipart/form-data`.
///
/// Extracted fields are sorted into alphabetical order by key, so if you wish
/// to use pattern matching the order can be relied upon.
///
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use form <- wisp.require_form(request)
///   case form.values {
///     [#("password", pass), #("username", username)] -> // ...
///     _ -> // ...
///   }
/// }
/// ```
///
/// The `set_max_body_size`, `set_max_files_size`, and `set_read_chunk_size` can
/// be used to configure the reading of the request body.
///
/// Any file uploads will streamed into temporary files on disc. These files are
/// automatically deleted when the request handler returns, so if you wish to
/// use them after the request has completed you will need to move them to a new
/// location.
///
/// If the request does not have a recognised `content-type` header then an
/// empty response with status code 415: Unsupported media type will be returned
/// to the client.
///
/// If the request body is larger than the `max_body_size` or `max_files_size`
/// limits then an empty response with status code 413: Entity too large will be
/// returned to the client.
///
/// If the body cannot be parsed successfully then an empty response with status
/// code 400: Bad request will be returned to the client.
///
pub fn require_form(
  request: Request,
  next: fn(FormData) -> Response,
) -> Response {
  case list.key_find(request.headers, "content-type") {
    Ok("application/x-www-form-urlencoded")
    | Ok("application/x-www-form-urlencoded;" <> _) ->
      require_urlencoded_form(request, next)

    Ok("multipart/form-data; boundary=" <> boundary) ->
      require_multipart_form(request, boundary, next)

    Ok("multipart/form-data") -> bad_request()

    _ ->
      unsupported_media_type([
        "application/x-www-form-urlencoded", "multipart/form-data",
      ])
  }
}

/// This middleware function ensures that the request has a value for the
/// `content-type` header, returning an empty response with status code 415:
/// Unsupported media type if the header is not the expected value
///
/// # Examples
///
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use <- wisp.require_content_type(request, "application/json")
///   // ...
/// }
/// ```
///
pub fn require_content_type(
  request: Request,
  expected: String,
  next: fn() -> Response,
) -> Response {
  case list.key_find(request.headers, "content-type") {
    Ok(content_type) ->
      // This header may have further such as `; charset=utf-8`, so discard
      // that if it exists.
      case string.split_once(content_type, ";") {
        Ok(#(content_type, _)) if content_type == expected -> next()
        _ if content_type == expected -> next()
        _ -> unsupported_media_type([expected])
      }

    _ -> unsupported_media_type([expected])
  }
}

/// A middleware which extracts JSON from the body of a request.
///
/// ```gleam
/// fn handle_request(request: Request) -> Response {
///   use json <- wisp.require_json(request)
///   // decode and use JSON here...
/// }
/// ```
///
/// The `set_max_body_size` and `set_read_chunk_size` can be used to configure
/// the reading of the request body.
///
/// If the request does not have the `content-type` set to `application/json` an
/// empty response with status code 415: Unsupported media type will be returned
/// to the client.
///
/// If the request body is larger than the `max_body_size` or `max_files_size`
/// limits then an empty response with status code 413: Entity too large will be
/// returned to the client.
///
/// If the body cannot be parsed successfully then an empty response with status
/// code 400: Bad request will be returned to the client.
///
pub fn require_json(request: Request, next: fn(Dynamic) -> Response) -> Response {
  use <- require_content_type(request, "application/json")
  use body <- require_string_body(request)
  use json <- or_400(json.decode(body, Ok))
  next(json)
}

fn require_urlencoded_form(
  request: Request,
  next: fn(FormData) -> Response,
) -> Response {
  use body <- require_string_body(request)
  use pairs <- or_400(uri.parse_query(body))
  let pairs = sort_keys(pairs)
  next(FormData(values: pairs, files: []))
}

fn require_multipart_form(
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
      let append = fn(data, chunk) { Ok(bit_array.append(data, chunk)) }
      let q = quotas.body
      let result =
        multipart_body(reader, parse, boundary, read_size, q, append, <<>>)
      use #(reader, quota, value) <- result.try(result)
      let quotas = Quotas(..quotas, body: quota)
      use value <- result.map(bit_array_to_string(value))
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

fn bit_array_to_string(bits: BitArray) -> Result(String, Response) {
  bit_array.to_string(bits)
  |> result.replace_error(bad_request())
}

fn multipart_file_append(
  path: String,
  chunk: BitArray,
) -> Result(String, Response) {
  simplifile.append_bits(path, chunk)
  |> or_500
  |> result.replace(path)
}

fn or_500(result: Result(a, b)) -> Result(a, Response) {
  case result {
    Ok(value) -> Ok(value)
    Error(error) -> {
      log_error(string.inspect(error))
      Error(internal_server_error())
    }
  }
}

fn multipart_body(
  reader: BufferedReader,
  parse: fn(BitArray) -> Result(http.MultipartBody, Response),
  boundary: String,
  chunk_size: Int,
  quota: Int,
  append: fn(t, BitArray) -> Result(t, Response),
  data: t,
) -> Result(#(Option(BufferedReader), Int, t), Response) {
  use #(chunk, reader) <- result.try(read_chunk(reader, chunk_size))
  let size_read = bit_array.byte_size(chunk)
  use output <- result.try(parse(chunk))

  case output {
    http.MultipartBody(parsed, done, remaining) -> {
      // Decrement the quota by the number of bytes consumed.
      let used = size_read - bit_array.byte_size(remaining) - 2
      let used = case done {
        // If this is the last chunk, we need to account for the boundary.
        True -> used - 4 - string.byte_size(boundary)
        False -> used
      }
      use quota <- result.try(decrement_quota(quota, used))

      let reader = BufferedReader(reader, remaining)
      let reader = case done {
        True -> option.None
        False -> option.Some(reader)
      }
      use value <- result.map(append(data, parsed))
      #(reader, quota, value)
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
) -> Result(#(BitArray, internal.Reader), Response) {
  buffered_read(reader, chunk_size)
  |> result.replace_error(bad_request())
  |> result.try(fn(chunk) {
    case chunk {
      internal.Chunk(chunk, next) -> Ok(#(chunk, next))
      internal.ReadingFinished -> Error(bad_request())
    }
  })
}

fn multipart_headers(
  reader: BufferedReader,
  parse: fn(BitArray) -> Result(http.MultipartHeaders, Response),
  chunk_size: Int,
  quotas: Quotas,
) -> Result(#(List(http.Header), BufferedReader, Quotas), Response) {
  use #(chunk, reader) <- result.try(read_chunk(reader, chunk_size))
  use headers <- result.try(parse(chunk))

  case headers {
    http.MultipartHeaders(headers, remaining) -> {
      let used = bit_array.byte_size(chunk) - bit_array.byte_size(remaining)
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

fn or_400(result: Result(value, error), next: fn(value) -> Response) -> Response {
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
  case exception.rescue(handler) {
    Ok(response) -> response
    Error(error) -> {
      let #(kind, detail) = case error {
        exception.Errored(detail) -> #(Errored, detail)
        exception.Thrown(detail) -> #(Thrown, detail)
        exception.Exited(detail) -> #(Exited, detail)
      }
      case dynamic.dict(atom.from_dynamic, Ok)(detail) {
        Ok(details) -> {
          let c = atom.create_from_string("class")
          log_error_dict(dict.insert(details, c, dynamic.from(kind)))
          Nil
        }
        Error(_) -> log_error(string.inspect(error))
      }
      internal_server_error()
    }
  }
}

type DoNotLeak

@external(erlang, "logger", "error")
fn log_error_dict(o: Dict(Atom, Dynamic)) -> DoNotLeak

type ErrorKind {
  Errored
  Thrown
  Exited
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
  |> log_info
  response
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
/// Typically you static assets may be kept in your project in a directory
/// called `priv`. The `priv_directory` function can be used to get a path to
/// this directory.
///
/// ```gleam
/// fn handle_request(req: Request) -> Response {
///   let assert Ok(priv) = priv_directory("my_application")
///   use <- wisp.serve_static(req, under: "/static", from: priv)
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
  let path = internal.remove_preceeding_slashes(req.path)
  let prefix = internal.remove_preceeding_slashes(prefix)
  case req.method, string.starts_with(path, prefix) {
    http.Get, True -> {
      let path =
        path
        |> string.drop_left(string.length(prefix))
        |> string.replace(each: "..", with: "")
        |> internal.join_path(directory, _)

      let mime_type =
        req.path
        |> string.split(on: ".")
        |> list.last
        |> result.unwrap("")
        |> marceau.extension_to_mime_type

      let content_type = case mime_type {
        "application/json" | "text/" <> _ -> mime_type <> "; charset=utf-8"
        _ -> mime_type
      }

      case simplifile.is_file(path) {
        Ok(True) ->
          response.new(200)
          |> response.set_header("content-type", content_type)
          |> response.set_body(File(path))
        _ -> handler()
      }
    }
    _, _ -> handler()
  }
}

/// A middleware function that converts `HEAD` requests to `GET` requests,
/// handles the request, and then discards the response body. This is useful so
/// that your application can handle `HEAD` requests without having to implement
/// handlers for them.
///
/// The `x-original-method` header is set to `"HEAD"` for requests that were
/// originally `HEAD` requests.
///
/// # Examples
///
/// ```gleam
/// fn handle_request(req: Request) -> Response {
///   use req <- wisp.handle_head(req)
///   // ...
/// }
/// ```
///
pub fn handle_head(
  req: Request,
  next handler: fn(Request) -> Response,
) -> Response {
  case req.method {
    http.Head ->
      req
      |> request.set_method(http.Get)
      |> request.prepend_header("x-original-method", "HEAD")
      |> handler
      |> response.set_body(Empty)
    _ -> handler(req)
  }
}

//
// File uploads
//

/// Create a new temporary directory for the given request.
///
/// If you are using the Mist adapter or another compliant web server
/// adapter then this file will be deleted for you when the request is complete.
/// Otherwise you will need to call the `delete_temporary_files` function
/// yourself.
///
pub fn new_temporary_file(
  request: Request,
) -> Result(String, simplifile.FileError) {
  let directory = request.body.temporary_directory
  use _ <- result.try(simplifile.create_directory_all(directory))
  let path = internal.join_path(directory, internal.random_slug())
  use _ <- result.map(simplifile.create_file(path))
  path
}

/// Delete any temporary files created for the given request.
///
/// If you are using the Mist adapter or another compliant web server
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

/// Returns the path of a package's `priv` directory, where extra non-Gleam
/// or Erlang files are typically kept.
///
/// Returns an error if no package was found with the given name.
///
/// # Example
///
/// ```gleam
/// > erlang.priv_directory("my_app")
/// // -> Ok("/some/location/my_app/priv")
/// ```
///
pub const priv_directory = erlang.priv_directory

//
// Logging
//

/// Configure the Erlang logger, setting the minimum log level to `info`, to be
/// called when your application starts.
///
/// You may wish to use an alternative for this such as one provided by a more
/// sophisticated logging library.
///
/// In future this function may be extended to change the output format.
///
pub fn configure_logger() -> Nil {
  logging.configure()
}

/// Type to set the log level of the Erlang's logger
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub type LogLevel {
  EmergencyLevel
  AlertLevel
  CriticalLevel
  ErrorLevel
  WarningLevel
  NoticeLevel
  InfoLevel
  DebugLevel
}

fn log_level_to_logging_log_level(log_level: LogLevel) -> logging.LogLevel {
  case log_level {
    EmergencyLevel -> logging.Emergency
    AlertLevel -> logging.Alert
    CriticalLevel -> logging.Critical
    ErrorLevel -> logging.Error
    WarningLevel -> logging.Warning
    NoticeLevel -> logging.Notice
    InfoLevel -> logging.Info
    DebugLevel -> logging.Debug
  }
}

/// Set the log level of the Erlang logger to `log_level`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn set_logger_level(log_level: LogLevel) -> Nil {
  logging.set_level(log_level_to_logging_log_level(log_level))
}

/// Log a message to the Erlang logger with the level of `emergency`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_emergency(message: String) -> Nil {
  logging.log(logging.Emergency, message)
}

/// Log a message to the Erlang logger with the level of `alert`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_alert(message: String) -> Nil {
  logging.log(logging.Alert, message)
}

/// Log a message to the Erlang logger with the level of `critical`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_critical(message: String) -> Nil {
  logging.log(logging.Critical, message)
}

/// Log a message to the Erlang logger with the level of `error`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_error(message: String) -> Nil {
  logging.log(logging.Error, message)
}

/// Log a message to the Erlang logger with the level of `warning`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_warning(message: String) -> Nil {
  logging.log(logging.Warning, message)
}

/// Log a message to the Erlang logger with the level of `notice`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_notice(message: String) -> Nil {
  logging.log(logging.Notice, message)
}

/// Log a message to the Erlang logger with the level of `info`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_info(message: String) -> Nil {
  logging.log(logging.Info, message)
}

/// Log a message to the Erlang logger with the level of `debug`.
///
/// See the [Erlang logger documentation][1] for more information.
///
/// [1]: https://www.erlang.org/doc/man/logger
///
pub fn log_debug(message: String) -> Nil {
  logging.log(logging.Debug, message)
}

//
// Cryptography
//

/// Generate a random string of the given length.
///
pub fn random_string(length: Int) -> String {
  internal.random_string(length)
}

/// Sign a message which can later be verified using the `verify_signed_message`
/// function to detect if the message has been tampered with.
///
/// Signed messages are not encrypted and can be read by anyone. They are not
/// suitable for storing sensitive information.
///
/// This function uses the secret key base from the request. If the secret
/// changes then the signature will no longer be verifiable.
///
pub fn sign_message(
  request: Request,
  message: BitArray,
  algorithm: crypto.HashAlgorithm,
) -> String {
  crypto.sign_message(message, <<request.body.secret_key_base:utf8>>, algorithm)
}

/// Verify a signed message which was signed using the `sign_message` function.
///
/// Returns the content of the message if the signature is valid, otherwise
/// returns an error.
///
/// This function uses the secret key base from the request. If the secret
/// changes then the signature will no longer be verifiable.
///
pub fn verify_signed_message(
  request: Request,
  message: String,
) -> Result(BitArray, Nil) {
  crypto.verify_signed_message(message, <<request.body.secret_key_base:utf8>>)
}

//
// Cookies
//

/// Set a cookie on the response. After `max_age` seconds the cookie will be
/// expired by the client.
///
/// This function will sign the value if the `security` parameter is set to
/// `Signed`, making it so the cookie cannot be tampered with by the client.
///
/// Values are base64 encoded so they can contain any characters you want, even
/// if they would not be permitted directly in a cookie.
///
/// Cookies are set using `gleam_http`'s default attributes for HTTPS. If you
/// wish for more control over the cookie attributes then you may want to use
/// the `gleam/http/cookie` module from the `gleam_http` package instead of this
/// function. Be sure to sign and escape the cookie value as needed.
///
/// # Examples
///
/// Setting a plain text cookie that the client can read and modify:
///
/// ```gleam
/// wisp.ok()
/// |> wisp.set_cookie(request, "id", "123", wisp.PlainText, 60 * 60)
/// ```
///
/// Setting a signed cookie that the client can read but not modify:
///
/// ```gleam
/// wisp.ok()
/// |> wisp.set_cookie(request, "id", value, wisp.Signed, 60 * 60)
/// ```
///
pub fn set_cookie(
  response response: Response,
  request request: Request,
  name name: String,
  value value: String,
  security security: Security,
  max_age max_age: Int,
) -> Response {
  let attributes =
    cookie.Attributes(
      ..cookie.defaults(http.Https),
      max_age: option.Some(max_age),
    )
  let value = case security {
    PlainText -> bit_array.base64_encode(<<value:utf8>>, False)
    Signed -> sign_message(request, <<value:utf8>>, crypto.Sha512)
  }
  response
  |> response.set_cookie(name, value, attributes)
}

pub type Security {
  /// The value is store as plain text without any additional security.
  /// The client will be able to read and modify the value, and create new values.
  PlainText
  /// The value is signed to prevent modification.
  /// The client will be able to read the value but not modify it, or create new
  /// values.
  Signed
}

/// Get a cookie from the request.
///
/// If a cookie is missing, found to be malformed, or the signature is invalid
/// for a signed cookie, then `Error(Nil)` is returned.
///
/// ```gleam
/// wisp.get_cookie(request, "group", wisp.PlainText)
/// // -> Ok("A")
/// ```
///
pub fn get_cookie(
  request: Request,
  name: String,
  security: Security,
) -> Result(String, Nil) {
  use value <- result.try(
    request
    |> request.get_cookies
    |> list.key_find(name),
  )
  use value <- result.try(case security {
    PlainText -> bit_array.base64_decode(value)
    Signed -> verify_signed_message(request, value)
  })
  bit_array.to_string(value)
}

//
// Testing
//

// TODO: chunk the body
/// Create a connection which will return the given body when read.
///
/// This function is intended for use in tests, though you probably want the
/// `wisp/testing` module instead.
///
pub fn create_canned_connection(
  body: BitArray,
  secret_key_base: String,
) -> internal.Connection {
  internal.make_connection(
    fn(_size) {
      Ok(internal.Chunk(body, fn(_size) { Ok(internal.ReadingFinished) }))
    },
    secret_key_base,
  )
}
