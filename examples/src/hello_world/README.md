# Wisp Example: Hello, world!

```sh
gleam run -m hello_world/app  # Run the server
```

This example shows a minimal Wisp application, it does nothing but respond with
a greeting to any request.

The project has this structure:

```
├─ app
│  ├─ router.gleam
│  └─ web.gleam
└─ app.gleam
```

In your project `app` would be replaced by the name of your application.

### `app` module

The entrypoint to the application. It performs initialisation and starts the
web server.

### `app/web` module

This module contains the application's middleware stack and any custom types,
middleware, and other functions that are used by the request handlers.

### `app/router` module

This module contains the application's request handlers. Or "handler" in this
case, as there's only one!

### Unit tests [examples/test/hello_world/](../../test/hello_world/)

The tests for the application.
