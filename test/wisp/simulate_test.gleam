import gleam/bit_array
import gleam/http
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/string
import wisp
import wisp/simulate

pub fn request_test() {
  let request = simulate.request(http.Patch, "/wibble/woo")
  assert request.method == http.Patch
  assert request.headers == [#("host", "wisp.example.com")]
  assert request.scheme == http.Https
  assert request.host == "wisp.example.com"
  assert request.port == None
  assert request.path == "/wibble/woo"
  assert request.query == None
  assert wisp.read_body_bits(request) == Ok(<<>>)
}

pub fn browser_request_test() {
  let request = simulate.browser_request(http.Put, "/wibble/woo")
  assert request.method == http.Put
  assert request.headers
    == [
      #("origin", "https://wisp.example.com"),
      #("host", "wisp.example.com"),
    ]
  assert request.scheme == http.Https
  assert request.host == "wisp.example.com"
  assert request.port == None
  assert request.path == "/wibble/woo"
  assert request.query == None
  assert wisp.read_body_bits(request) == Ok(<<>>)
}

pub fn text_body_test() {
  let request =
    simulate.request(http.Patch, "/wibble/woo")
    |> simulate.string_body("Hello, Joe!")
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "text/plain"),
    ]
  assert wisp.read_body_bits(request) == Ok(<<"Hello, Joe!">>)
}

pub fn binary_body_test() {
  let request =
    simulate.request(http.Patch, "/wibble/woo")
    |> simulate.bit_array_body(<<123>>)
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "application/octet-stream"),
    ]
  assert wisp.read_body_bits(request) == Ok(<<123>>)
}

pub fn form_body_test() {
  let request =
    simulate.request(http.Patch, "/wibble/woo")
    |> simulate.form_body([#("a", "1"), #("b", "2")])
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "application/x-www-form-urlencoded"),
    ]
  assert wisp.read_body_bits(request) == Ok(<<"a=1&b=2">>)
}

pub fn json_body_test() {
  let request =
    simulate.request(http.Patch, "/wibble/woo")
    |> simulate.json_body(
      json.object([
        #("a", json.int(1)),
        #("b", json.int(2)),
      ]),
    )
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "application/json"),
    ]
  assert wisp.read_body_bits(request) == Ok(<<"{\"a\":1,\"b\":2}">>)
}

pub fn read_text_body_file_test() {
  assert wisp.ok()
    |> response.set_body(wisp.File("test/fixture.txt", 0, None))
    |> simulate.read_body
    == "Hello, Joe! 👨‍👩‍👧‍👦\n"
}

pub fn read_text_body_text_test() {
  assert wisp.ok()
    |> response.set_body(wisp.Text("Hello, Joe!"))
    |> simulate.read_body
    == "Hello, Joe!"
}

pub fn read_binary_body_file_test() {
  assert wisp.ok()
    |> response.set_body(wisp.File("test/fixture.txt", 0, None))
    |> simulate.read_body_bits
    == <<"Hello, Joe! 👨‍👩‍👧‍👦\n":utf8>>
}

pub fn read_binary_body_text_test() {
  assert wisp.ok()
    |> response.set_body(wisp.Text("Hello, Joe!"))
    |> simulate.read_body_bits
    == <<"Hello, Joe!":utf8>>
}

pub fn request_query_string_test() {
  let request = simulate.request(http.Patch, "/wibble/woo?one=two&three=four")

  assert request.host == "wisp.example.com"
  assert request.path == "/wibble/woo"
  assert request.query == option.Some("one=two&three=four")
}

pub fn header_test() {
  let request = simulate.request(http.Get, "/")

  assert request.headers == [#("host", "wisp.example.com")]

  // Set new headers
  let request =
    request
    |> simulate.header("content-type", "application/json")
    |> simulate.header("accept", "application/json")
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "application/json"),
      #("accept", "application/json"),
    ]

  // Replace the header
  let request = simulate.header(request, "content-type", "text/plain")
  assert request.headers
    == [
      #("host", "wisp.example.com"),
      #("content-type", "text/plain"),
      #("accept", "application/json"),
    ]
}

pub fn cookie_plain_text_test() {
  let req =
    simulate.browser_request(http.Get, "/")
    |> simulate.cookie("abc", "1234", wisp.PlainText)
    |> simulate.cookie("def", "5678", wisp.PlainText)
  assert req.headers
    == [
      #("cookie", "abc=MTIzNA; def=NTY3OA"),
      #("origin", "https://wisp.example.com"),
      #("host", "wisp.example.com"),
    ]
}

pub fn cookie_signed_test() {
  let req =
    simulate.browser_request(http.Get, "/")
    |> simulate.cookie("abc", "1234", wisp.Signed)
    |> simulate.cookie("def", "5678", wisp.Signed)
  assert req.headers
    == [
      #(
        "cookie",
        "abc=SFM1MTI.MTIzNA.QWGuB_lZLssnh71rC6R5_WOr8MDr8dxE3C_2JvLRAAC4ad4SnmQk0Fl_6_RrtmzdH2O3WaNPExkJsuwBixtWIA; def=SFM1MTI.NTY3OA.R3HRe5woa1qwxvjRUC5ggQVd3hTqGCXIk_4ybU35SXPtGvLrFpHBXWGIjyG5QeuEk9j3jnWIL3ct18olJiSCMw",
      ),
      #("origin", "https://wisp.example.com"),
      #("host", "wisp.example.com"),
    ]
}

pub fn session_test() {
  // Initial cookies
  let request =
    simulate.browser_request(http.Get, "/")
    |> simulate.cookie("zero", "0", wisp.PlainText)
    |> simulate.cookie("one", "1", wisp.PlainText)
    |> simulate.cookie("two", "2", wisp.PlainText)
  assert list.key_find(request.headers, "cookie")
    == Ok("zero=MA; one=MQ; two=Mg")

  // A response from the server that changes the cookies.
  // - one: changed value
  // - two: expired
  // - three: newly added
  let response =
    wisp.ok()
    |> wisp.set_cookie(request, "one", "11", wisp.PlainText, 100)
    |> wisp.set_cookie(request, "two", "2", wisp.PlainText, 0)
    |> wisp.set_cookie(request, "three", "3", wisp.PlainText, 100)

  // Continue the session
  let request =
    simulate.browser_request(http.Get, "/")
    |> simulate.session(request, response)

  assert list.key_find(request.headers, "cookie")
    == Ok("zero=MA; one=MTE; three=Mw")
}

pub fn multipart_body_test() {
  let file1 = simulate.uploaded_text_file("file1", "test.txt", "Hello, world!")
  let file2 =
    simulate.uploaded_file("file2", "data.bin", "application/octet-stream", <<
      1,
      2,
      3,
      4,
    >>)

  let request =
    simulate.request(http.Post, "/upload")
    |> simulate.multipart_body(
      [#("name", "test"), #("description", "A test file")],
      [file1, file2],
    )

  let assert Ok(content_type) = list.key_find(request.headers, "content-type")
  assert string.starts_with(content_type, "multipart/form-data; boundary=")

  let body_bits = case wisp.read_body_bits(request) {
    Ok(bits) -> bits
    Error(_) -> <<>>
  }
  let body_string = case bit_array.to_string(body_bits) {
    Ok(s) -> s
    Error(_) -> ""
  }

  assert body_string |> string.contains("name=\"name\"") == True
  assert body_string |> string.contains("test") == True
  assert body_string |> string.contains("name=\"description\"") == True
  assert body_string |> string.contains("A test file") == True

  // Check for file content
  assert body_string |> string.contains("name=\"file1\"") == True
  assert body_string |> string.contains("filename=\"test.txt\"") == True
  assert body_string |> string.contains("Content-Type: text/plain") == True
  assert body_string |> string.contains("Hello, world!") == True

  assert body_string |> string.contains("name=\"file2\"") == True
  assert body_string |> string.contains("filename=\"data.bin\"") == True
  assert body_string
    |> string.contains("Content-Type: application/octet-stream")
    == True
}

pub fn uploaded_file_test() {
  let file =
    simulate.uploaded_file("test-file", "example.jpg", "image/jpeg", <<
      "fake image data":utf8,
    >>)

  assert file.name == "test-file"
  assert file.filename == "example.jpg"
  assert file.content_type == "image/jpeg"
  assert file.content == <<"fake image data":utf8>>
}

pub fn uploaded_text_file_test() {
  let file =
    simulate.uploaded_text_file("doc", "readme.txt", "Documentation text")

  assert file.name == "doc"
  assert file.filename == "readme.txt"
  assert file.content_type == "text/plain"
  assert file.content == <<"Documentation text":utf8>>
}

pub fn multipart_generation_validation_test() {
  let file =
    simulate.uploaded_text_file("uploaded-file", "test.txt", "Hello, world!")
  let request =
    simulate.browser_request(http.Post, "/upload")
    |> simulate.multipart_body([#("name", "test")], [file])

  let content_type = list.key_find(request.headers, "content-type")
  assert case content_type {
    Ok(ct) -> string.starts_with(ct, "multipart/form-data; boundary=")
    Error(_) -> False
  }

  let body_result = wisp.read_body_bits(request)
  assert case body_result {
    Ok(bits) -> bit_array.byte_size(bits) > 50
    Error(_) -> False
  }
}
