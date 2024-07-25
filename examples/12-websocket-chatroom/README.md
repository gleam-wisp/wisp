# Wisp Example: Websocket Chatroom

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to create a central chatroom actor which the websocket
handler will register and communicate with to allow broadcasting messages
between all connected clients.

This example builds off of the ["websockets" example][websockets] so read that
one first. The additions are detailed here and commented in the code.

[websockets]: https://github.com/lpil/wisp/tree/main/examples/11-websockets

### `app` module

We start up our chatroom actor.

### `app/router` module

Here we add an additional login page.

We also add an input field for the chatroom page to allow sending things other
than ping.

### `app/web` module

We include our chatroom actor's subject into our Context type.

### `app/websocket` module

We update our State details and our on_init function to communicate with our
new chatroom actor.

Our disconnect function is also updated to notify the chatroom actor.

### `app/chatroom` module

This newly created module handles the events, state and co-ordination of
clients and messages between all of our active websocket connections.
