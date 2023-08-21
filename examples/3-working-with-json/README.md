# Wisp Example: Routing

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to read JSON from a request and return JSON in the
response.

This example is based off of the ["Hello, World!" example][hello], and uses
concepts from the [routing example][routing] so read those first. The additions
are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/0-hello-world
[routing]: https://github.com/lpil/wisp/tree/main/examples/0-routing

### `app/router` module

The `handle_request` function has been updated to read JSON from the
request body, decode it using the Gleam standard library, and return JSON
back to the client.

### `app_test` module

Tests have been added that send requests with JSON bodies and check that the
expected response is returned.

### Other modules

No changes have been made to the other modules.
