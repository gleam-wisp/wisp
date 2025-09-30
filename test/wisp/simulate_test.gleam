import gleam/erlang/process
import gleam/http
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/string
import simplifile
import wisp
import wisp/simulate
import wisp/websocket

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
  let file1 = simulate.FileUpload("test.txt", "text/plain", <<"Hello, world!">>)
  let file2 =
    simulate.FileUpload("data.bin", "application/octet-stream", <<
      1,
      2,
      3,
      4,
    >>)

  let request =
    simulate.request(http.Post, "/upload")
    |> simulate.multipart_body(
      [#("name", "test"), #("description", "A test file")],
      [#("file1", file1), #("file2", file2)],
    )

  let assert Ok(content_type) = list.key_find(request.headers, "content-type")
  assert string.starts_with(content_type, "multipart/form-data; boundary=")

  {
    use formdata <- wisp.require_form(request)
    let assert [#("file1", file1), #("file2", file2)] = formdata.files
    assert "test.txt" == file1.file_name
    assert simplifile.read(file1.path) == Ok("Hello, world!")
    assert "data.bin" == file2.file_name
    assert simplifile.read_bits(file2.path) == Ok(<<1, 2, 3, 4>>)
    wisp.ok()
  }
}

pub fn multipart_generation_validation_test() {
  let file = simulate.FileUpload("test.txt", "text/plain", <<"Hello, world!">>)
  let request =
    simulate.browser_request(http.Post, "/upload")
    |> simulate.multipart_body([#("name", "test")], [#("uploaded-file", file)])

  let assert Ok("multipart/form-data; boundary=" <> boundary) =
    list.key_find(request.headers, "content-type")

  let assert Ok(body) = wisp.read_body_bits(request)
  let expected_body =
    "--"
    <> boundary
    <> "\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\ntest\r\n--"
    <> boundary
    <> "\r\nContent-Disposition: form-data; name=\"uploaded-file\"; filename=\"test.txt\"\r\nContent-Type: text/plain\r\n\r\nHello, world!\r\n--"
    <> boundary
    <> "--\r\n"
  assert body == <<expected_body:utf8>>
}

/// Test WebSocket message handling with the simulate module
pub fn websocket_echo_message_test() {
  // Create a simple echo handler
  let echo_handler =
    websocket.handler(
      on_init: fn(_) { "echo_state" },
      on_message: fn(state, message, _connection) {
        case message {
          websocket.Text(text) -> websocket.Continue("echoed: " <> text)
          websocket.Binary(_) -> websocket.Continue(state)
          websocket.Closed -> websocket.Stop
          websocket.Shutdown -> websocket.Stop
        }
      },
      on_close: fn(_) { Nil },
    )

  // Test with a text message
  let mock_connection = simulate.websocket_connection()
  let #(result, _final_connection) =
    simulate.websocket_handler_message(
      echo_handler,
      "initial_state",
      websocket.Text("hello"),
      mock_connection,
    )

  // Check that the handler processed the message correctly
  let assert websocket.Continue("echoed: hello") = result
}

pub fn websocket_ping_message_test() {
  let ping_handler =
    websocket.handler(
      on_init: fn(_) { 0 },
      on_message: fn(state, message, _connection) {
        case message {
          websocket.Text("ping") -> websocket.Continue(state + 1)
          websocket.Text("reset") -> websocket.Continue(0)
          _ -> websocket.Continue(state)
        }
      },
      on_close: fn(_) { Nil },
    )

  let mock_connection = simulate.websocket_connection()

  // Test ping message
  let #(result, _) =
    simulate.websocket_handler_message(
      ping_handler,
      5,
      websocket.Text("ping"),
      mock_connection,
    )

  let assert websocket.Continue(6) = result

  // Test reset message
  let #(result, _) =
    simulate.websocket_handler_message(
      ping_handler,
      10,
      websocket.Text("reset"),
      mock_connection,
    )

  let assert websocket.Continue(0) = result
}

/// Test WebSocket handler with close message
pub fn websocket_close_message_test() {
  let close_handler =
    websocket.handler(
      on_init: fn(_) { "active" },
      on_message: fn(_state, message, _connection) {
        case message {
          websocket.Closed -> websocket.Stop
          websocket.Shutdown -> websocket.StopWithError("shutdown")
          _ -> websocket.Continue("still_active")
        }
      },
      on_close: fn(_) { Nil },
    )

  let connection = simulate.websocket_connection()

  // Test close message
  let #(result, _) =
    simulate.websocket_handler_message(
      close_handler,
      "active",
      websocket.Closed,
      connection,
    )

  let assert websocket.Stop = result

  // Test shutdown message
  let #(result, _) =
    simulate.websocket_handler_message(
      close_handler,
      "active",
      websocket.Shutdown,
      connection,
    )

  let assert websocket.StopWithError("shutdown") = result
}

/// Test WebSocket handler with binary message
pub fn websocket_binary_message_test() {
  let binary_handler =
    websocket.handler(
      on_init: fn(_) { 0 },
      on_message: fn(state, message, _connection) {
        case message {
pub fn mock_websocket_connection_test() {
  // Create a mock websocket connection
  let assert Ok(#(mock, connection)) = simulate.websocket_connection()

  // Initially, no messages should be sent
  assert simulate.get_sent_text_messages(mock) == []
  assert simulate.get_sent_binary_messages(mock) == []
  assert simulate.is_connection_closed(mock) == False

  // Send a text message
  let assert Ok(_) = websocket.send_text(connection, "Hello, WebSocket!")

  // Check that the message was captured
  assert simulate.get_sent_text_messages(mock) == ["Hello, WebSocket!"]
  assert simulate.get_sent_binary_messages(mock) == []
  assert simulate.is_connection_closed(mock) == False

  // Send a binary message
  let assert Ok(_) = websocket.send_binary(connection, <<"Binary data">>)

  // Check that both messages were captured
  assert simulate.get_sent_text_messages(mock) == ["Hello, WebSocket!"]
  assert simulate.get_sent_binary_messages(mock) == [<<"Binary data">>]
  assert simulate.is_connection_closed(mock) == False

  let assert Ok(_) = websocket.send_text(connection, "Second message")
  assert simulate.get_sent_text_messages(mock)
    == ["Hello, WebSocket!", "Second message"]

  assert simulate.get_sent_binary_messages(mock) == [<<"Binary data">>]
  assert simulate.is_connection_closed(mock) == False

  let assert Ok(_) = websocket.close_connection(connection)

  assert simulate.is_connection_closed(mock) == True
  assert simulate.get_sent_text_messages(mock)
    == ["Hello, WebSocket!", "Second message"]
  assert simulate.get_sent_binary_messages(mock) == [<<"Binary data">>]

  simulate.reset_mock(mock)

  assert simulate.get_sent_text_messages(mock) == []
  assert simulate.get_sent_binary_messages(mock) == []
  assert simulate.is_connection_closed(mock) == False
}

pub fn websocket_handler_simulation_test() {
  let websocket_handler =
pub fn websocket_handler_test() {
  let state_subject = process.new_subject()
  let handler =
    websocket.new(
      fn(_conn) {
        let initial_state = "Initial State"
        process.send(state_subject, initial_state)
        #(initial_state, option.None)
      },
      fn(state, message, connection) {
        case message {
          websocket.Text(text) -> {
            let message = "Echo: " <> text
            let new_state = state <> " | " <> message
            let assert Ok(_) = websocket.send_text(connection, message)
            process.send(state_subject, new_state)
            websocket.Continue(new_state)
          }
          websocket.Binary(data) -> {
            let new_state = state <> " | " <> "Binary"
            let assert Ok(_) = websocket.send_binary(connection, data)
            process.send(state_subject, new_state)
            websocket.Continue(new_state)
          }
          websocket.Closed | websocket.Shutdown -> {
            websocket.Stop
          }
          websocket.Custom(_) -> {
            let new_state = state <> " | Custom"
            process.send(state_subject, new_state)
            websocket.Continue(new_state)
          }
        }
      },
      fn(state) { process.send(state_subject, state) },
    )

  let assert Ok(websocket) = simulate.create_websocket(handler)
  let assert Ok("Initial State") = process.receive(state_subject, 1000)

  let assert Ok(websocket) = simulate.send_websocket_text(websocket, "Hello")
  let assert [] = simulate.websocket_sent_binary_messages(websocket)
  let assert ["Echo: Hello"] = simulate.websocket_sent_text_messages(websocket)
  let assert Ok("Initial State | Echo: Hello") =
    process.receive(state_subject, 1000)

  let assert Ok(websocket) =
    simulate.send_websocket_binary(websocket, <<1, 2, 3>>)
  let assert [<<1, 2, 3>>] = simulate.websocket_sent_binary_messages(websocket)
  let assert ["Echo: Hello"] = simulate.websocket_sent_text_messages(websocket)
  let assert Ok("Initial State | Echo: Hello | Binary") =
    process.receive(state_subject, 1000)

  let assert Ok(Nil) = simulate.close_websocket(websocket)
  let assert Ok("Initial State | Echo: Hello | Binary") =
    process.receive(state_subject, 1000)

  let assert Ok(websocket) =
    simulate.send_websocket_binary(websocket, <<4, 5, 6>>)
  let assert [<<1, 2, 3>>] = simulate.websocket_sent_binary_messages(websocket)

  let websocket = simulate.reset_websocket(websocket)
  let assert Ok("Initial State") = process.receive(state_subject, 1000)
  let assert Ok(websocket) =
    simulate.send_websocket_binary(websocket, <<6, 7, 8>>)
  let assert [<<6, 7, 8>>] = simulate.websocket_sent_binary_messages(websocket)
  let assert Ok("Initial State | Binary") = process.receive(state_subject, 1000)
}
