import app/web
import app/websocket
import gleam/http.{Get}
import gleam/http/request
import gleam/string
import gleam/string_builder
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> login_page(req)
    ["chatroom"] -> {
      chat_room_page(req)
    }
    ["ws"] -> websocket.chat_server(req, ctx)
    _ -> wisp.not_found()
  }
}

// A simple login page where we prompt the user for a username and then
// redirect them to the chatroom page.
fn login_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let html = string_builder.from_string(login)
  wisp.ok() |> wisp.html_body(html)
}

// Our chatroom page, where we extract the username from the url parameters
// provided through the login page.
//
// In a real system, you would would use cookies to store the users session
// (see example 08-working-with-cookies) but for this example application we
// are using query parameters to make it easier to 'login' in multiple browser
// tabs for demonstration purposes.
fn chat_room_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  let assert Ok([#("username", username)]) = request.get_query(req)
  let html =
    client
    |> string.replace("%username%", username)
    |> string_builder.from_string
  wisp.ok()
  |> wisp.html_body(html)
}

const login = "
<body>
  <h1>Login to chat</h1>
  <form method='get' action='chatroom'>
    <label>Username:
      <input name='username' required='true'>
    </label>
    <input type='submit' value='Submit'>
  </form>
</body>

"

const client = "
<body>

  <h1>Hello, Joe!</h1>
  <button onclick='send_ping()'>send ping</button>
  <br />
  <input>
  <br />
  <p id='msg'></p>

  <script>
  // Create WebSocket connection.
  const socket = new WebSocket('http://localhost:8000/ws?username=%username%');

  // Connection opened
  socket.addEventListener('open', (event) => {
    socket.send('ping');
  });

  // Listen for messages
  socket.addEventListener('message', (event) => {
    console.log('Message from server ', event.data);
    document.querySelector('#msg').insertAdjacentHTML('afterend','<p>' + event.data + '</p>');
  });

  function send_ping() {
      socket.send('ping');
  }

  // Handle sending input messages and clearing the text
  var chatbox = document.querySelector('input');
  chatbox.addEventListener('keyup', (event) => {
    if (event.key === 'Enter') {
      socket.send(chatbox.value);
      chatbox.value = '';
    }
  });
  </script>

</body>
"
