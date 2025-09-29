import gleam/int
import wisp.{type Request, type Response}
import wisp/websocket

pub fn handle_request(request: Request) -> Response {
  use <- wisp.log_request(request)

  case wisp.path_segments(request) {
    [] -> home_page()
    ["websocket"] -> websocket_handler(request)
    _ -> wisp.not_found()
  }
}

fn home_page() -> Response {
  let html =
    "<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Echo Example</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        #messages { border: 1px solid #ccc; height: 300px; overflow-y: scroll; padding: 10px; margin: 10px 0; }
        input[type=\"text\"] { width: 300px; padding: 5px; }
        button { padding: 5px 10px; }
        .message { margin: 5px 0; }
        .sent { color: blue; }
        .received { color: green; }
        .status { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>WebSocket Echo Example</h1>
    <p>This example demonstrates WebSocket support in Wisp.</p>

    <div>
        <button onclick=\"connect()\">Connect</button>
        <button onclick=\"disconnect()\">Disconnect</button>
        <span id=\"status\">Disconnected</span>
    </div>

    <div id=\"messages\"></div>

    <div>
        <input type=\"text\" id=\"messageInput\" placeholder=\"Type your message...\" onkeypress=\"if(event.key==='Enter') sendMessage()\">
        <button onclick=\"sendMessage()\">Send</button>
    </div>

    <script>
        let ws = null;
        const messages = document.getElementById('messages');
        const status = document.getElementById('status');
        const messageInput = document.getElementById('messageInput');

        function addMessage(content, className) {
            const div = document.createElement('div');
            div.className = 'message ' + className;
            div.textContent = content;
            messages.appendChild(div);
            messages.scrollTop = messages.scrollHeight;
        }

        function connect() {
            if (ws) {
                ws.close();
            }

            ws = new WebSocket('ws://localhost:8001/websocket');

            ws.onopen = function(event) {
                status.textContent = 'Connected';
                addMessage('Connected to WebSocket', 'status');
            };

            ws.onmessage = function(event) {
                addMessage('Received: ' + event.data, 'received');
            };

            ws.onclose = function(event) {
                status.textContent = 'Disconnected';
                addMessage('WebSocket connection closed', 'status');
            };

            ws.onerror = function(error) {
                addMessage('WebSocket error: ' + error, 'status');
            };
        }

        function disconnect() {
            if (ws) {
                ws.close();
            }
        }

        function sendMessage() {
            if (ws && ws.readyState === WebSocket.OPEN) {
                const message = messageInput.value;
                if (message) {
                    ws.send(message);
                    addMessage('Sent: ' + message, 'sent');
                    messageInput.value = '';
                }
            } else {
                addMessage('WebSocket is not connected', 'status');
            }
        }
    </script>
</body>
</html>"

  wisp.html_response(html, 200)
}

fn websocket_handler(request: Request) -> Response {
  wisp.websocket(
    request,
    on_init: fn(_connection) { 0 },
    on_message: fn(state, message, connection) {
      case message {
        websocket.Text(text) -> {
          let count = state + 1
          let response = "Echo #" <> int.to_string(count) <> ": " <> text
          case websocket.send_text(connection, response) {
            Ok(_) -> websocket.continue(count)
            Error(_) -> websocket.stop_with_error("Failed to send message")
          }
        }
        websocket.Binary(binary) -> {
          // Echo binary messages back
          case websocket.send_binary(connection, binary) {
            Ok(_) -> websocket.continue(state)
            Error(_) ->
              websocket.stop_with_error("Failed to send binary message")
          }
        }
        websocket.Closed -> {
          websocket.stop()
        }
        websocket.Shutdown -> {
          websocket.stop()
        }
      }
    },
    on_close: fn(_state) {
      // Cleanup when connection closes
      Nil
    },
  )
}
