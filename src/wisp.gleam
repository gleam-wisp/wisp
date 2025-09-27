import exception
import filepath
import gleam/bit_array
import gleam/bool
import gleam/bytes_tree.{type BytesTree}
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/application
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
import gleam/string_tree.{type StringTree}
import gleam/uri
import houdini
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
  /// If you have a `StringTree` you can use the `bytes_tree.from_string_tree`
  /// function with the `Bytes` variant instead, as this will avoid the cost of
  /// converting the tree into a string.
  ///
  Text(String)
  /// A body of binary data, stored as a `BytesTree`.
  ///
  /// If you have a `BitArray` you can use the `bytes_tree.from_bit_array`
  /// function to convert it.
  ///
  /// If you have a `StringTree` you can use the `bytes_tree.from_string_tree`
  /// function to convert it.
  ///
  Bytes(BytesTree)
  /// A body of the contents of a file.
  ///
  /// This will be sent efficiently using the `send_file` function of the
  /// underlying HTTP server. The file will not be read into memory so it is
  /// safe to send large files this way.
  ///
  File(
    /// The path to the file on the server file system.
    path: String,
    /// The number of bytes to skip from the start of the file. Set to 0 for the whole file.
    offset: Int,
    /// The maximum number of bytes to send. Set to `None` for the whole file.
    limit: Option(Int),
  )
}

/// An alias for a HTTP response containing a `Body`.
pub type Response =
  HttpResponse(Body)

/// Create a response with the given status code.
///
/// # Examples
///
/// ```gleam
/// response(200)
/// // -> Response(200, [], Text(""))
/// ```
///
pub fn response(status: Int) -> Response {
  HttpResponse(status, [], Text(""))
}

/// Set the body of a response.
///
/// # Examples
///
/// ```gleam
/// response(200)
/// |> set_body(File("/tmp/myfile.txt", option.None))
/// // -> Response(200, [], File("/tmp/myfile.txt", option.None))
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
/// //   File("/tmp/myfile.txt", option.None),
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
  |> response.set_body(File(path:, offset: 0, limit: option.None))
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
/// let content = bytes_tree.from_string("Hello, Joe!")
/// response(200)
/// |> file_download_from_memory(named: "myfile.txt", containing: content)
/// // -> Response(
/// //   200,
/// //   [#("content-disposition", "attachment; filename=\"myfile.txt\"")],
/// //   File("/tmp/myfile.txt", option.None),
/// // )
/// ```
///
pub fn file_download_from_memory(
  response: Response,
  named name: String,
  containing data: BytesTree,
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
/// The `content-type` header will be set to `text/html; charset=utf-8`.
///
/// # Examples
///
/// ```gleam
/// html_response("<h1>Hello, Joe!</h1>", 200)
/// // -> Response(200, [#("content-type", "text/html; charset=utf-8")], Text(body))
/// ```
///
pub fn html_response(html: String, status: Int) -> Response {
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
/// json_response("{\"name\": \"Joe\"}", 200)
/// // -> Response(200, [#("content-type", "application/json")], Text(body))
/// ```
///
pub fn json_response(json: String, status: Int) -> Response {
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
/// response(201)
/// |> html_body("<h1>Hello, Joe!</h1>")
/// // -> Response(201, [#("content-type", "text/html; charset=utf-8")], Text(body))
/// ```
///
pub fn html_body(response: Response, html: String) -> Response {
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
/// response(201)
/// |> json_body("{\"name\": \"Joe\"}")
/// // -> Response(201, [#("content-type", "application/json; charset=utf-8")], Text(body))
/// ```
///
pub fn json_body(response: Response, json: String) -> Response {
  response
  |> response.set_body(Text(json))
  |> response.set_header("content-type", "application/json; charset=utf-8")
}

/// Set the body of a response to a given string tree.
///
/// You likely want to also set the request `content-type` header to an
/// appropriate value for the format of the content.
///
/// # Examples
///
/// ```gleam
/// let body = string_tree.from_string("Hello, Joe!")
/// response(201)
/// |> string_tree_body(body)
/// // -> Response(201, [], Text(body))
/// ```
///
pub fn string_tree_body(response: Response, content: StringTree) -> Response {
  response
  |> response.set_body(Bytes(bytes_tree.from_string_tree(content)))
}

/// Set the body of a response to a given string.
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
/// // -> Response(201, [], Text("Hello, Joe"))
/// ```
///
pub fn string_body(response: Response, content: String) -> Response {
  response
  |> response.set_body(Text(content))
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
  houdini.escape(content)
}

/// Create a response with status code 405: Method Not Allowed. Use this
/// when a request does not have an appropriate method to be handled.
///
/// The `allow` header will be set to a comma separated list of the permitted
/// methods.
///
/// # Examples
///
/// ```gleam
/// method_not_allowed(allowed: [Get, Post])
/// // -> Response(405, [#("allow", "GET, POST")], Text("Method not allowed"))
/// ```
///
pub fn method_not_allowed(allowed methods: List(Method)) -> Response {
  let allowed =
    methods
    |> list.map(http.method_to_string)
    |> list.sort(string.compare)
    |> string.join(", ")
    |> string.uppercase
  HttpResponse(405, [#("allow", allowed)], Text("Method not allowed"))
}

/// Create a response with status code 200: OK.
///
/// # Examples
///
/// ```gleam
/// ok()
/// // -> Response(200, [#("content-type", "text/plain")], Text("OK"))
/// ```
///
pub fn ok() -> Response {
  HttpResponse(200, [content_text], Text("OK"))
}

/// Create a response with status code 201: Created.
///
/// # Examples
///
/// ```gleam
/// created()
/// // -> Response(201, [#("content-type", "text/plain")], Text("Created"))
/// ```
///
pub fn created() -> Response {
  HttpResponse(201, [content_text], Text("Created"))
}

/// Create a response with status code 202: Accepted.
///
/// # Examples
///
/// ```gleam
/// accepted()
/// // -> Response(202, [#("content-type", "text/plain")], Text("Accepted"))
/// ```
///
pub fn accepted() -> Response {
  HttpResponse(202, [content_text], Text("Accepted"))
}

/// Create a response with status code 303: See Other, and the `location`
/// header set to the given URL. Used to redirect the client to another page.
///
/// # Examples
///
/// ```gleam
/// redirect(to: "https://example.com")
/// // -> Response(
/// //   303,
/// //   [#("location", "https://example.com"), #("context-type", "text/plain")],
/// //   Text("You are being redirected: https://example.com"),
/// // )
/// ```
///
pub fn redirect(to url: String) -> Response {
  HttpResponse(
    303,
    [#("location", url), content_text],
    Text("You are being redirected: " <> url),
  )
}

/// Create a response with status code 308: Permanent redirect, and the
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
/// // -> Response(
/// //   303,
/// //   [#("location", "https://example.com")],
/// //   Text("You are being redirected: https://example.com"),
/// // )
/// ```
///
pub fn permanent_redirect(to url: String) -> Response {
  HttpResponse(
    308,
    [#("location", url), content_text],
    Text("You are being redirected: " <> url),
  )
}

/// Create a response with status code 204: No content.
///
/// # Examples
///
/// ```gleam
/// no_content()
/// // -> Response(204, [], Text(""))
/// ```
///
pub fn no_content() -> Response {
  HttpResponse(204, [], Text(""))
}

/// Create a response with status code 404: Not found.
///
/// # Examples
///
/// ```gleam
/// not_found()
/// // -> Response(404, [#("content-type", "text/plain")], Text("Not found"))
/// ```
///
pub fn not_found() -> Response {
  HttpResponse(404, [content_text], Text("Not found"))
}

/// Create a response with status code 400: Bad request.
///
/// # Examples
///
/// ```gleam
/// bad_request("Invalid JSON")
/// // -> Response(400, [#("content-type", "text/plain")], Text("Bad request: Invalid JSON"))
/// ```
///
pub fn bad_request(detail: String) -> Response {
  let body = case detail {
    "" -> "Bad request"
    _ -> "Bad request: " <> detail
  }
  HttpResponse(400, [content_text], Text(body))
}

/// Create a response with status code 413: Content too large.
///
/// # Examples
///
/// ```gleam
/// content_too_large()
/// // -> Response(413, [#("content-type", "text/plain")], Text("Content too large"))
/// ```
///
pub fn content_too_large() -> Response {
  HttpResponse(413, [content_text], Text("Content too large"))
}

/// Create a response with status code 415: Unsupported media type.
///
/// The `allow` header will be set to a comma separated list of the permitted
/// content-types.
///
/// # Examples
///
/// ```gleam
/// unsupported_media_type(accept: ["application/json", "text/plain"])
/// // -> Response(415, [#("allow", "application/json, text/plain")], Text("Unsupported media type"))
/// ```
///
pub fn unsupported_media_type(accept acceptable: List(String)) -> Response {
  let acceptable = string.join(acceptable, ", ")
  HttpResponse(
    415,
    [#("accept", acceptable), content_text],
    Text("Unsupported media type"),
  )
}

/// Create a response with status code 422: Unprocessable content.
///
/// # Examples
///
/// ```gleam
/// unprocessable_content()
/// // -> Response(422, [#("content-type", "text/plain")], Text("Unprocessable content"))
/// ```
///
pub fn unprocessable_content() -> Response {
  HttpResponse(422, [content_text], Text("Unprocessable content"))
}

/// Create a response with status code 500: Internal server error.
///
/// # Examples
///
/// ```gleam
/// internal_server_error()
/// // -> Response(500, [#("content-type", "text/plain")], Text("Internal server error"))
/// ```
///
pub fn internal_server_error() -> Response {
  HttpResponse(500, [content_text], Text("Internal server error"))
}

const content_text = #("content-type", "text/plain")

const invalid_json = "Invalid JSON"

const invalid_form = "Invalid form encoding"

const invalid_utf8 = "Invalid UTF-8"

const invalid_range = "Invalid range"

const invalid_content_disposition = "Invalid content-disposition"

const invalid_host = "Invalid host"

const invalid_origin = "Invalid origin"

const unexpected_end = "Unexpected end of request body"

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
    True -> Error(content_too_large())
    False -> Ok(quotas)
  }
}

fn decrement_quota(quota: Int, size: Int) -> Result(Int, Response) {
  case quota - size {
    quota if quota < 0 -> Error(content_too_large())
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
/// in a response with status code 413: Content too large will be returned to the
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
/// 413: Content too large will be returned to the client.
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
/// method, returning a response with status code 405: Method not allowed
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
/// Request(200, [#("content-type", "application/json")], Text("OK"))
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
/// ```html
/// <form method="POST" action="/item/1?_method=DELETE">
///   <button type="submit">Delete item</button>
/// </form>
/// ```
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

// TODO: don't always return content too large. Other errors are possible, such as
// network errors.
/// A middleware function which reads the entire body of the request as a string.
///
/// This function does not cache the body in any way, so if you call this
/// function (or any other body reading function) more than once it may hang or
/// return an incorrect value, depending on the underlying web server. It is the
/// responsibility of the caller to cache the body if it is needed multiple
/// times.
///
/// If the body is larger than the `max_body_size` limit then a response
/// with status code 413: Content too large will be returned to the client.
///
/// If the body is found not to be valid UTF-8 then a response with
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
  case read_body_bits(request) {
    Ok(body) ->
      case bit_array.to_string(body) {
        Ok(body) -> next(body)
        Error(_) -> bad_request(invalid_utf8)
      }
    Error(_) -> content_too_large()
  }
}

// TODO: don't always return content too large. Other errors are possible, such as
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
/// If the body is larger than the `max_body_size` limit then a response
/// with status code 413: Content too large will be returned to the client.
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
  case read_body_bits(request) {
    Ok(body) -> next(body)
    Error(_) -> content_too_large()
  }
}

// TODO: don't always return content to large. Other errors are possible, such as
// network errors.
/// Read the entire body of the request as a bit array.
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
/// If the body is larger than the `max_body_size` limit then a response
/// with status code 413: Content too large will be returned to the client.
///
pub fn read_body_bits(request: Request) -> Result(BitArray, Nil) {
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
/// If the request does not have a recognised `content-type` header then a
/// response with status code 415: Unsupported media type will be returned
/// to the client.
///
/// If the request body is larger than the `max_body_size` or `max_files_size`
/// limits then a response with status code 413: Content too large will be
/// returned to the client.
///
/// If the body cannot be parsed successfully then a response with status
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

    Ok("multipart/form-data") -> bad_request(invalid_form)

    _ ->
      unsupported_media_type([
        "application/x-www-form-urlencoded", "multipart/form-data",
      ])
  }
}

/// This middleware function ensures that the request has a value for the
/// `content-type` header, returning a response with status code 415:
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
/// If the request does not have the `content-type` set to `application/json` a
/// response with status code 415: Unsupported media type will be returned
/// to the client.
///
/// If the request body is larger than the `max_body_size` or `max_files_size`
/// limits then a response with status code 413: Content too large will be
/// returned to the client.
///
/// If the body cannot be parsed successfully then a response with status
/// code 400: Bad request will be returned to the client.
///
pub fn require_json(request: Request, next: fn(Dynamic) -> Response) -> Response {
  use <- require_content_type(request, "application/json")
  use body <- require_string_body(request)
  case json.parse(body, decode.dynamic) {
    Ok(json) -> next(json)
    Error(_) -> bad_request(invalid_json)
  }
}

fn require_urlencoded_form(
  request: Request,
  next: fn(FormData) -> Response,
) -> Response {
  use body <- require_string_body(request)
  case uri.parse_query(body) {
    Ok(pairs) -> {
      let pairs = sort_keys(pairs)
      next(FormData(values: pairs, files: []))
    }
    Error(_) -> bad_request(invalid_form)
  }
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
    fn_with_bad_request_error(
      http.parse_multipart_headers(_, boundary),
      invalid_form,
    )
  let result = multipart_headers(reader, header_parser, read_size, quotas)
  use #(headers, reader, quotas) <- result.try(result)
  use #(name, filename) <- result.try(multipart_content_disposition(headers))

  // Then we read the body of the part.
  let parse =
    fn_with_bad_request_error(
      http.parse_multipart_body(_, boundary),
      invalid_form,
    )
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
      use value <- result.map(case bit_array.to_string(value) {
        Ok(string) -> Ok(string)
        Error(_) -> Error(bad_request(invalid_utf8))
      })
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
      let parse = fn_with_bad_request_error(parse, invalid_form)
      let reader = BufferedReader(reader, <<>>)
      use data <- result.try(append(data, chunk))
      multipart_body(reader, parse, boundary, chunk_size, quota, append, data)
    }
  }
}

fn fn_with_bad_request_error(
  f: fn(a) -> Result(b, c),
  error: String,
) -> fn(a) -> Result(b, Response) {
  fn(a) {
    case f(a) {
      Ok(x) -> Ok(x)
      Error(_) -> Error(bad_request(error))
    }
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
  |> result.replace_error(bad_request(invalid_content_disposition))
}

fn read_chunk(
  reader: BufferedReader,
  chunk_size: Int,
) -> Result(#(BitArray, internal.Reader), Response) {
  case buffered_read(reader, chunk_size) {
    Error(_) -> Error(bad_request(unexpected_end))
    Ok(chunk) ->
      case chunk {
        internal.Chunk(chunk, next) -> Ok(#(chunk, next))
        internal.ReadingFinished -> Error(bad_request(unexpected_end))
      }
  }
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
        case parse(chunk) {
          Ok(parsed) -> Ok(parsed)
          Error(_) -> Error(bad_request(invalid_form))
        }
      }
      let reader = BufferedReader(reader, <<>>)
      multipart_headers(reader, parse, chunk_size, quotas)
    }
  }
}

fn sort_keys(pairs: List(#(String, t))) -> List(#(String, t)) {
  list.sort(pairs, fn(a, b) { string.compare(a.0, b.0) })
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

/// A middleware function that rescues crashes and returns a response
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
      case decode.run(detail, atom_dict_decoder()) {
        Ok(details) -> {
          let c = atom.create("class")
          log_error_dict(dict.insert(details, c, error_kind_to_dynamic(kind)))
          Nil
        }
        Error(_) -> log_error(string.inspect(error))
      }
      internal_server_error()
    }
  }
}

@external(erlang, "gleam@function", "identity")
fn error_kind_to_dynamic(kind: ErrorKind) -> Dynamic

fn atom_dict_decoder() -> decode.Decoder(Dict(Atom, Dynamic)) {
  let atom =
    decode.new_primitive_decoder("Atom", fn(data) {
      case atom_from_dynamic(data) {
        Ok(atom) -> Ok(atom)
        Error(_) -> Error(atom.create("nil"))
      }
    })
  decode.dict(atom, decode.dynamic)
}

@external(erlang, "wisp_ffi", "atom_from_dynamic")
fn atom_from_dynamic(data: Dynamic) -> Result(Atom, Nil)

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
        |> string.drop_start(string.length(prefix))
        |> string.replace(each: "..", with: "")
        |> filepath.join(directory, _)

      let file_type =
        req.path
        |> string.split(on: ".")
        |> list.last
        |> result.unwrap("")

      let mime_type = marceau.extension_to_mime_type(file_type)
      let content_type = case mime_type {
        "application/json" | "text/" <> _ -> mime_type <> "; charset=utf-8"
        _ -> mime_type
      }

      case simplifile.file_info(path) {
        Ok(file_info) ->
          case simplifile.file_info_type(file_info) {
            simplifile.File -> {
              response.new(200)
              |> response.set_header("content-type", content_type)
              |> response.set_body(File(path:, offset: 0, limit: option.None))
              |> handle_etag(req, file_info)
              |> handle_file_range_header(req, file_info, path)
            }
            _ -> handler()
          }
        _ -> handler()
      }
    }
    _, _ -> handler()
  }
}

/// The value of a `range` request header.
///
pub type Range {
  Range(
    /// The number of bytes to skip from the start of the content. 0 would be
    /// the start of the file.
    ///
    /// A negative offset is an offset backwards from the end of the content.
    offset: Int,
    /// The maximum number of bytes in the range. `None` would mean the rest of
    /// the file.
    limit: Option(Int),
  )
}

/// Parses the content of a range header.
///
/// # Example
///
/// ```gleam
/// wisp.parse_range_header("bytes=-64")
/// // -> Ok(Range(offset: -64, limit: option.None))
/// ```
///
pub fn parse_range_header(range_header: String) -> Result(Range, Nil) {
  case range_header {
    "bytes=" <> range -> {
      use #(start_str, end_str) <- result.try(range |> string.split_once("-"))

      case start_str, end_str {
        // "range: bytes=-[tail]"
        "", _ ->
          int.parse(end_str)
          |> result.map(fn(tail_offset) {
            Range(offset: -tail_offset, limit: option.None)
          })

        // "range: bytes=[start]-"
        _, "" ->
          int.parse(start_str)
          |> result.map(fn(offset) { Range(offset:, limit: option.None) })

        // "range: bytes=[start]-[end]"
        _, _ -> {
          use offset <- result.try(int.parse(start_str))
          use end <- result.try(int.parse(end_str))

          Ok(Range(offset:, limit: option.Some(end - offset + 1)))
        }
      }
    }
    _ -> Error(Nil)
  }
}

/// Checks for the `range` header and handles partial file reads.
///
/// If the range request header is present, it will set the `accept-ranges`,
/// `content-range`, and `content-length` response headers. If the range
/// request header has a range that is out of bounds of the file, it will
/// respond with a `416 Range Not Satisfiable`.
///
/// If the header isn't present, it returns the input response without changes.
fn handle_file_range_header(
  resp: Response,
  req: Request,
  file_info: simplifile.FileInfo,
  path: String,
) -> Response {
  let result = {
    use raw_range <- result.try(
      request.get_header(req, "range") |> result.replace_error(resp),
    )

    use range <- result.try(
      parse_range_header(raw_range)
      |> result.replace_error(bad_request(invalid_range)),
    )

    let range = case range.offset < 0 {
      True -> Range(..range, offset: file_info.size + range.offset)
      False -> range
    }

    let end_is_invalid =
      range.limit
      |> option.map(fn(end) {
        end < 0 || end >= file_info.size || end < range.offset
      })
      |> option.unwrap(False)

    use <- bool.guard(
      range.offset < 0 || range.offset >= file_info.size || end_is_invalid,
      Error(
        response(416)
        |> response.prepend_header("range", "bytes=*"),
      ),
    )

    let content_range = {
      let end = case range.limit {
        option.Some(l) -> { range.offset + l - 1 } |> int.to_string
        option.None -> { file_info.size - 1 } |> int.max(0) |> int.to_string
      }

      "bytes "
      <> int.to_string(range.offset)
      <> "-"
      <> end
      <> "/"
      <> int.to_string(file_info.size)
    }

    let content_length = case range.limit {
      option.Some(l) -> int.to_string(l)
      option.None -> int.to_string(file_info.size - range.offset)
    }

    response.Response(
      206,
      resp.headers,
      File(path:, offset: range.offset, limit: range.limit),
    )
    |> response.set_header("content-length", content_length)
    |> response.set_header("accept-ranges", "bytes")
    |> response.set_header("content-range", content_range)
    |> Ok
  }

  case result {
    Error(response) -> response
    Ok(response) -> response
  }
}

/// Calculates etag for requested file and then checks for the request header `if-none-match`.
///
/// If the header isn't present or the value doesn't match the newly generated etag, it returns the file with the newly generated etag.
/// Otherwise if the etag matches, it returns status 304 without the file, allowing the browser to use the cached version.
///
fn handle_etag(
  resp: Response,
  req: Request,
  file_info: simplifile.FileInfo,
) -> Response {
  let etag = internal.generate_etag(file_info.size, file_info.mtime_seconds)

  case request.get_header(req, "if-none-match") {
    Ok(old_etag) if old_etag == etag ->
      response(304)
      |> set_header("etag", etag)
    _ -> response.set_header(resp, "etag", etag)
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
  let path = filepath.join(directory, internal.random_slug())
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
pub const priv_directory = application.priv_directory

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
/// If you wish for more control over the cookie attributes then you may want
/// to use the `gleam/http/cookie` module from the `gleam_http` package.
///
/// # Security
///
/// - `PlainText`: the cookie value is base64 encoded. This permits use of any
///    characters in the cookie, but it is possible for the client to edit the
///    cookie, potentially maliciously.
/// - `Signed`: the cookie value will be signed with `sign_message` and so
///    cannot be tampered with by the client.
///
/// # `Secure` cookie attribute
///
/// This function sets the `Secure` cookie attribute (with one exception detailed
/// below), ensuring that browsers will only send the cookie over HTTPS
/// connections.
///
/// Most browsers consider localhost to be secure and permit `Secure` cookies
/// for those requests as well, but Safari does not. For cookies to work in
/// development for programmers using a browser like Safari the `Secure`
/// attribute will not be set if all these conditions are met:
///
/// - The request scheme is `http://`.
/// - The request host is `localhost`, `127.0.0.1`, or `[::1]`.
/// - The `x-forwarded-proto` header has not been set, indicating that the
///   request is not from a reverse proxy such as Caddy or Nginx.
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
  let scheme = case request.host {
    "localhost" | "127.0.0.1" | "[::1]" if request.scheme == http.Http ->
      case request.get_header(request, "x-forwarded-proto") {
        Ok(_) -> http.Https
        Error(_) -> http.Http
      }
    _ -> http.Https
  }
  let attributes =
    cookie.Attributes(..cookie.defaults(scheme), max_age: option.Some(max_age))
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
/// # Security
///
/// - `PlainText`: the cookie value is expected to be base64 encoded.
/// - `Signed`: the cookie value is expected to be signed with `sign_message`.
///
/// # Examples
///
/// ```gleam
/// wisp.get_cookie(request, "group", wisp.PlainText)
/// // -> Ok("A")
/// ```
///
pub fn get_cookie(
  request request: Request,
  name name: String,
  security security: Security,
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
@internal
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

/// Cross-Site Request Forgery (CSRF) attacks by checking the `host` request
/// header against the `origin` header or `referer` header.
///
/// - Requests with the `Get` and `Head` methods are accepted.
/// - Requests with no `host` header are rejected with status 400: Bad Request.
/// - Requests with no `origin` or `referer` headers are accepted, but have the
///   `cookie` header removed to prevent CSRF attacks against cookie based
///   sessions.
/// - Requests with origin/referer headers that match their host header are
///   accepted.
/// - Requests with headers that don't match are rejected with status 400: Bad
///   Request.
///
/// This middleware implements the [OWASP Verifying Origin With Standard Headers][1]
/// CSRF defense-in-depth technique. **Do not** allow `Get` or `Head` requests 
/// to trigger side effects if relying only on this function and the SameSite
/// cookies feature for CSRF protection.
///
/// This middleware and SameSite cookies typically is sufficient to protect
/// against CSRF attacks, but you may decide to employ [token based mitigation][2]
/// for more complete CSRF defence-in-depth.
///
/// [1]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#using-standard-headers-to-verify-origin
/// [2]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#token-based-mitigation
///
pub fn csrf_known_header_protection(
  request: Request,
  next: fn(Request) -> Response,
) -> Response {
  let is_pure_method = case request.method {
    http.Head | http.Get -> True
    _ -> False
  }

  // GET and HEAD are pure methods, so they SHOULD NOT perform side effects.
  // If there are no side effects then there's no risk of CSRF attacks.
  use <- bool.lazy_guard(when: is_pure_method, return: fn() { next(request) })

  // The origin and referer headers are set by the browser.
  // https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Origin
  // https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referer
  let origin = case request.get_header(request, "origin") {
    Error(_) -> request.get_header(request, "referer")
    Ok(_) as o -> o
  }

  // The host header is required for HTTP1.1, but not HTTP1.0 or HTTP2/3.
  // This would need to be modified to support HTTP3 in future.
  // https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Host
  let host = request.get_header(request, "host")

  case origin, host {
    _, Error(_) -> {
      log_warning("Host header missing from request")
      bad_request(invalid_host)
    }
    // If the request does not have origin headers then we cannot perform an
    // origin check, so we must remove the cookie headers to ensure that a CSRF
    // attack is not possible.
    Error(_), _ -> {
      let headers = list.filter(request.headers, fn(h) { h.0 != "cookie" })
      let request = request.Request(..request, headers:)
      next(request)
    }
    Ok(origin), Ok(host) -> {
      let #(host_host, host_port) = case string.split_once(host, ":") {
        Ok(#(host, port)) -> {
          let port = port |> int.parse |> option.from_result
          #(option.Some(host), port)
        }
        _ -> #(option.Some(host), option.None)
      }

      let uri.Uri(host: origin_host, port: origin_port, ..) =
        uri.parse(origin) |> result.unwrap(uri.empty)

      case host_host == origin_host && host_port == origin_port {
        True -> next(request)
        False -> {
          log_warning("Origin-host mismatch: " <> host <> " " <> origin)
          bad_request(invalid_origin)
        }
      }
    }
  }
}
