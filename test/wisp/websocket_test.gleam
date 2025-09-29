import exception
import gleam/http
import wisp
import wisp/simulate
import wisp/websocket

pub fn websocket_response_test() {
  let request = simulate.request(http.Get, "/websocket")

  let response =
    wisp.websocket(
      request,
      on_init: fn(_) { "initial_state" },
      on_message: fn(state, message, _connection) {
        case message {
          websocket.Text("echo: " <> _) -> websocket.Continue(state)
          websocket.Text(_) -> websocket.Continue(state)
          websocket.Binary(_) -> websocket.Continue(state)
          websocket.Closed -> websocket.Stop
          websocket.Shutdown -> websocket.Stop
        }
      },
      on_close: fn(_) { Nil },
    )

  assert response.status == 200
  assert response.headers == []
  let assert wisp.WebSocket(_) = response.body
}

pub fn websocket_upgrade_request_test() {
  let handler = fn(request: wisp.Request) -> wisp.Response(_) {
    case wisp.path_segments(request) {
      ["websocket"] -> {
        wisp.websocket(
          request,
          on_init: fn(_) { "test_state" },
          on_message: fn(state, _message, _connection) {
            websocket.Continue(state)
          },
          on_close: fn(_) { Nil },
        )
      }
      _ -> wisp.not_found()
    }
  }

  let request = simulate.request(http.Get, "/websocket")
  let response = handler(request)

  let assert wisp.WebSocket(_) = response.body
  assert response.status == 200
  assert response.headers == []

  let request = simulate.request(http.Get, "/not-websocket")
  let response = handler(request)
  assert response.status == 404
}

pub fn websocket_upgrade_headers_test() {
  let handler = fn(request: wisp.Request) -> wisp.Response(_) {
    wisp.websocket(
      request,
      on_init: fn(_) { 0 },
      on_message: fn(state, _message, _connection) { websocket.Continue(state) },
      on_close: fn(_) { Nil },
    )
  }

  let request = simulate.websocket_request(http.Get, "/websocket")

  let headers = request.headers
  let assert [
    #("host", "wisp.example.com"),
    #("connection", "Upgrade"),
    #("upgrade", "websocket"),
    #("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="),
    #("sec-websocket-version", "13"),
  ] = headers

  let response = handler(request)
  let assert wisp.WebSocket(_) = response.body
  assert response.status == 200
}

pub fn websocket_handler_extraction_test() {
  let request = simulate.request(http.Get, "/websocket")
  let on_init = fn(_) { "test_initial_state" }
  let on_message = fn(state, message, _connection) {
    case message {
      websocket.Text("ping") -> websocket.Continue("pong")
      _ -> websocket.Continue(state)
    }
  }

  let response =
    wisp.websocket(request, on_init:, on_message:, on_close: fn(_) { Nil })

  let websocket_handler = simulate.expect_websocket_upgrade(response)
  assert websocket_handler |> websocket.on_init == on_init
  assert websocket_handler |> websocket.on_message == on_message
}

pub fn non_websocket_handler_extraction_fails_test() {
  let response = wisp.ok()

  let assert Error(_) =
    exception.rescue(fn() { simulate.expect_websocket_upgrade(response) })
}
