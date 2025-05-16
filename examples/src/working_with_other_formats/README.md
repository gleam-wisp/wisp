# Wisp Example: Working with other formats

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to read and return formats that do not have special
support in Wisp. In this case we'll use CSV, but the same techniques can be used
for any format.

This example is based off of the ["Hello, World!" example][hello], and uses
concepts from the [routing example][routing] so read those first. The additions
are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/src/hello_world
[routing]: https://github.com/lpil/wisp/tree/main/examples/src/routing

### `gleam.toml` file

The `gsv` CSV package has been added as a dependency.

### `app/router` module

The `handle_request` function has been updated to read a string from the
request body, decode it using the `gsv` library, and return some CSV data
back to the client.

### `app_test` module

Tests have been added that send requests with CSV bodies and check that the
expected response is returned.

### Other files

No changes have been made to the other files.
