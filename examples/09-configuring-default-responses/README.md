# Wisp Example: Working with form data

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

Wisp has a response body value called `Empty`, which is just that: an empty
body. It can be returned by middleware functions such as `wisp.require_json`
when the request isn't suitable for request handler to run, such as if the
request body contains invalid JSON.

You likely want your application to return a generic error page rather than an empty body, and this example shows how to do that.

This example is based off of the [routing example][routing] so read that first.
The additions are detailed here and commented in the code.

[routing]: https://github.com/lpil/wisp/tree/main/examples/01-routing

### `app/router` module

The `handle_request` function has been updated to return responses with the
`wisp.Empty` body.

### `app/web` module

The `middleware` function has been updated to return default responses when an
`wisp.Empty` response body is returned.

### `app_test` module

Tests have been added to test each of the .

### Other files

No changes have been made to the other files.
