import app/web
import app/websocket
import gleam/http.{Get}
import gleam/string_builder
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> home_page(req)
    ["ws"] -> websocket.ping_pong(req, ctx.ws)
    _ -> wisp.not_found()
  }
}

fn home_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let html = string_builder.from_string(client)
  wisp.ok()
  |> wisp.html_body(html)
}

// Here we setup our index page as a websocket client This will connect to our
// websocket and print anything that it receieves from the websocket (note:
// unsafe as we do not escape the text). 
// 
// On first load we should see 'connected' and 'pong', as our server let us
// know we are connected in the `on_init` function and our client sents a
// 'ping' message immediately upon connecting, from which the server responsed
// 'pong'.
// 
// We can then press the 'send ping' button to send more messages, which will
// add the response to the dom.
const client = "
<body>

  <h1>Hello, Joe!</h1>
  <button onclick='send_ping()'>send ping</button>
  <p id='msg'></p>

  <script>
  // Create WebSocket connection.
  const socket = new WebSocket('http://localhost:8000/ws');

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
  </script>

</body>
"
