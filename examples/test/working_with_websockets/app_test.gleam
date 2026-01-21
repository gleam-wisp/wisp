import gleam/http
import wisp
import wisp/simulate
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

  let assert wisp.WebSocket(_) = response.body
}

pub fn websocket_text_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let assert wisp.WebSocket(upgrade) = response.body
  let handler = wisp.recover(upgrade)
  let assert Ok(ws) = simulate.create_websocket(handler)

  // Send first text message
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Hello")
  let assert ["Echo #1: Hello"] = simulate.websocket_sent_text_messages(ws)
  let assert [] = simulate.websocket_sent_binary_messages(ws)

  // Send second text message
  let assert Ok(ws) = simulate.send_websocket_text(ws, "World")
  let assert ["Echo #1: Hello", "Echo #2: World"] =
    simulate.websocket_sent_text_messages(ws)

  // Send third text message
  let assert Ok(ws) = simulate.send_websocket_text(ws, "!")
  let assert ["Echo #1: Hello", "Echo #2: World", "Echo #3: !"] =
    simulate.websocket_sent_text_messages(ws)
}

pub fn websocket_binary_echo_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let assert wisp.WebSocket(upgrade) = response.body
  let handler = wisp.recover(upgrade)
  let assert Ok(ws) = simulate.create_websocket(handler)

  // Send binary message
  let assert Ok(ws) = simulate.send_websocket_binary(ws, <<1, 2, 3>>)
  let assert [<<1, 2, 3>>] = simulate.websocket_sent_binary_messages(ws)
  let assert [] = simulate.websocket_sent_text_messages(ws)

  // Send another binary message
  let assert Ok(ws) = simulate.send_websocket_binary(ws, <<4, 5, 6>>)
  let assert [<<1, 2, 3>>, <<4, 5, 6>>] =
    simulate.websocket_sent_binary_messages(ws)
}

pub fn websocket_mixed_messages_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let assert wisp.WebSocket(upgrade) = response.body
  let handler = wisp.recover(upgrade)
  let assert Ok(ws) = simulate.create_websocket(handler)

  // Send text message
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Text message")
  let assert ["Echo #1: Text message"] =
    simulate.websocket_sent_text_messages(ws)

  // Send binary message (doesn't increment count)
  let assert Ok(ws) = simulate.send_websocket_binary(ws, <<7, 8, 9>>)
  let assert [<<7, 8, 9>>] = simulate.websocket_sent_binary_messages(ws)

  // Send another text message (count should be 2)
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Another text")
  let assert ["Echo #1: Text message", "Echo #2: Another text"] =
    simulate.websocket_sent_text_messages(ws)
}

pub fn websocket_close_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let assert wisp.WebSocket(upgrade) = response.body
  let handler = wisp.recover(upgrade)
  let assert Ok(ws) = simulate.create_websocket(handler)

  // Send some messages
  let assert Ok(ws) = simulate.send_websocket_text(ws, "First")
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Second")
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Third")

  let assert ["Echo #1: First", "Echo #2: Second", "Echo #3: Third"] =
    simulate.websocket_sent_text_messages(ws)

  // Close the websocket - should succeed
  let assert Ok(Nil) = simulate.close_websocket(ws)
}

pub fn websocket_closed_ignores_messages_test() {
  let request = simulate.websocket_request(http.Get, "/websocket")
  let response = router.handle_request(request)

  let assert wisp.WebSocket(upgrade) = response.body
  let handler = wisp.recover(upgrade)
  let assert Ok(ws) = simulate.create_websocket(handler)

  // Send a message
  let assert Ok(ws) = simulate.send_websocket_text(ws, "Before close")
  let assert ["Echo #1: Before close"] =
    simulate.websocket_sent_text_messages(ws)

  // Close the websocket
  let assert Ok(Nil) = simulate.close_websocket(ws)

  // Try to send messages after closing
  let assert Ok(ws) = simulate.send_websocket_text(ws, "After close")
  let assert Ok(ws) = simulate.send_websocket_binary(ws, <<10, 11, 12>>)

  // Messages should not be processed
  let assert ["Echo #1: Before close"] =
    simulate.websocket_sent_text_messages(ws)
  let assert [] = simulate.websocket_sent_binary_messages(ws)
}
