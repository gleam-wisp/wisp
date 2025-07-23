import gleam/http
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{None}
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
