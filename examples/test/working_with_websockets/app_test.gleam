import gleam/dynamic
import gleam/http
import wisp
import wisp/simulate
import wisp/websocket
import working_with_websockets/app/router

pub fn get_home_page_test() {
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request)

  assert response.status == 200
  assert response.headers == [#("content-type", "text/html; charset=utf-8")]
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

pub fn websocket_text_message_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_callbacks = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  let initial_state = dynamic.int(0)

  // Test first text message
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_callbacks,
      initial_state,
      websocket.Text("Hello World"),
      mock_connection,
    )

  let assert websocket.Continue(new_state) = result
  assert final_connection.sent_texts == ["Echo #1: Hello World"]
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False

  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_callbacks,
      new_state,
      websocket.Text("Second message"),
      mock_connection,
    )

  let assert websocket.Continue(_) = result
  assert final_connection.sent_texts == ["Echo #2: Second message"]
}

pub fn websocket_binary_message_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_callbacks = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()
  let binary_data = <<"Binary test data":utf8>>

  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_callbacks,
      dynamic.int(5),
      websocket.Binary(binary_data),
      mock_connection,
    )

  let assert websocket.Continue(_state) = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == [binary_data]
  assert final_connection.closed == False
}

pub fn websocket_close_message_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_callbacks = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_callbacks,
      dynamic.int(3),
      websocket.Closed,
      mock_connection,
    )

  let assert websocket.Stop = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False
}

pub fn websocket_shutdown_message_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_callbacks = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_callbacks,
      dynamic.int(10),
      websocket.Shutdown,
      mock_connection,
    )

  let assert websocket.Stop = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False
}
