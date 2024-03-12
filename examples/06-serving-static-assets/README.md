# Wisp Example: Serving static assets

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to route requests to different handlers based on the
request path and method.

This example is based off of the ["Hello, World!" example][hello], so read that
one first. The additions are detailed here and commented in the code.

[hello]: https://github.com/lpil/wisp/tree/main/examples/01-routing

### `priv/static` directory

This directory contains the static assets that will be served by the application.

### `app/web` module

A `Context` type has been defined to hold the path to the directory containing
the static assets.

The `serve_static` middleware has been added to the middleware stack to serve
the static assets.

### `app` module

The `main` function now starts by determining the path to the static assets
directory and constructs a `Context` record to pass to the handler function.

### `app/router` module

The `handle_request` function now returns a page of HTML.

### `app_test` module

Tests have been added to ensure that the static assets are served correctly.

### Other files

No changes have been made to the other files.
