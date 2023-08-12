# Wisp Example: Routing

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to route requests to different handlers based on the
request path and method.

This example is based off of the ["Hello, World!" example][hello], so read that
one first. The additions are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/0-hello-world

### `app/router` module

The `handle_request` function now pattern matches on the request and calls other
request handler functions depending on where the request should go.

### `app_test` module

Tests have been added for each of the routes. The `wisp/testing` module is used
to create different requests to test the application with.

### Other modules

No changes have been made to the other modules.
