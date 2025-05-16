# Wisp Example: Working with form data

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to read urlencoded and multipart formdata from a request

This example is based off of the ["Hello, World!" example][hello], and uses
concepts from the [routing example][routing] so read those first. The additions
are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/src/hello_world
[routing]: https://github.com/lpil/wisp/tree/main/examples/src/routing

### `app/router` module

The `handle_request` function has been updated to read the form data from the
request body and make use of values from it.

### `app_test` module

Tests have been added that send requests with form data bodies and check that
the expected response is returned.

### Other files

No changes have been made to the other files.
