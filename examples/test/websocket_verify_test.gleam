import gleam/http
import wisp/simulate
import wisp/websocket
import working_with_websockets/app/router

pub fn websocket_message_capture_verification_test() {
  // Test that demonstrates the new WebSocket message capture functionality
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)
  let websocket_handler = simulate.expect_websocket_upgrade(response)

  let mock_connection = simulate.websocket_connection()

  // Send a text message and verify it's echoed back correctly
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      0,
      websocket.Text("Test Message"),
      mock_connection,
    )

  // Verify the handler processed the message correctly
  let assert websocket.Continue(1) = result

  // THIS IS THE KEY TEST: Verify that sent messages are actually captured
  // This would have been empty/incomplete before our fix
  assert final_connection.sent_texts == ["Echo #1: Test Message"]
  assert final_connection.sent_binaries == []
  assert final_connection.closed == False

  // Test binary message capture as well
  let #(result, final_connection) =
    simulate.websocket_message(
      websocket_handler,
      5,
      websocket.Binary(<<"Binary data":utf8>>),
      mock_connection,
    )

  let assert websocket.Continue(5) = result
  assert final_connection.sent_texts == []
  assert final_connection.sent_binaries == [<<"Binary data":utf8>>]
  assert final_connection.closed == False
}