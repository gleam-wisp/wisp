# Wisp Example: Logging

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to route requests to different handlers based on the
request path and method.

This example is based off of the ["routing" example][routing], so read that
one first. The additions are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/1-routing

### `app/router` module

The `handle_request` function now logs messages depending on the request.

### Other files

No changes have been made to the other files.
