# Wisp Example: Routing

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to create a websocket handler and also provides a
websocket client on the home-page to perform a sequence of 'ping/pong'
operations between the two.

### `app/router` module

Here we setup the routes and also provide our client implementation.

### `app/websocket` module

This provides our websocket server implementation for our ping pong server.
