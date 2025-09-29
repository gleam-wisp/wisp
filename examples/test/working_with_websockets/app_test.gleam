import gleam/http
import gleam/string
import wisp
import wisp/simulate
import wisp/websocket
import working_with_websockets/app/router

pub fn get_home_page_test() {
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request)

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let body = simulate.read_body(response)

  // Verify the HTML contains key elements
  assert body |> wisp_test_contains("WebSocket Echo Example")
  assert body |> wisp_test_contains("Connect")
  assert body |> wisp_test_contains("Disconnect")
  assert body |> wisp_test_contains("ws://localhost:8001/websocket")
}

pub fn page_not_found_test() {
  let request = simulate.browser_request(http.Get, "/nothing-here")
  let response = router.handle_request(request)

  assert response.status == 404
}

pub fn websocket_upgrade_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  assert response.status == 200
  assert response.headers == []

  // Verify it's a WebSocket response
  let assert wisp.WebSocket(_) = response.body
}

pub fn websocket_handler_extraction_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let websocket_handler = simulate.expect_websocket_upgrade(response)

  // Test the initial state
  let test_connection = websocket.make_connection(
    fn(_) { Ok(Nil) },
    fn(_) { Ok(Nil) },
    fn() { Ok(Nil) },
  )
  let initial_state = websocket.on_init(websocket_handler)(test_connection)
  assert initial_state == 0
}

pub fn websocket_text_message_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_handler = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  // Test first text message
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      0,
      websocket.Text("Hello World"),
      mock_connection,
    )

  // Check that the handler processed the message correctly
  let assert websocket.Continue(1) = result
  assert final_connection.sent_texts == ["Echo #1: Hello World"]
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False

  // Test second text message with updated state
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      1,
      websocket.Text("Second message"),
      mock_connection,
    )

  let assert websocket.Continue(2) = result
  assert final_connection.sent_texts == ["Echo #2: Second message"]
}

pub fn websocket_binary_message_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_handler = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()
  let binary_data = <<"Binary test data":utf8>>

  // Test binary message echo
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      5,
      websocket.Binary(binary_data),
      mock_connection,
    )

  // Check that the handler echoed the binary message
  let assert websocket.Continue(5) = result  // State should remain the same for binary
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == [binary_data]
  assert final_connection.closed == False
}

pub fn websocket_close_message_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_handler = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  // Test close message
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      3,
      websocket.Closed,
      mock_connection,
    )

  let assert websocket.Stop = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False  // Handler doesn't call close, just stops
}

pub fn websocket_shutdown_message_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_handler = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  // Test shutdown message
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      10,
      websocket.Shutdown,
      mock_connection,
    )

  let assert websocket.Stop = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False  // Handler doesn't call close, just stops
}

// Helper function to check if a string contains a substring
fn wisp_test_contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}