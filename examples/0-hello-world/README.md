# Wisp Example: Hello, world!

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows a minimal Wisp application, it does nothing but respond with
a greeting to any request.

The project has this structure:

```
├─ src
│  ├─ app
│  │  ├─ router.gleam
│  │  └─ web.gleam
│  └─ app.gleam
└─ test
   └── app_test.gleam
```

### `app` module

The entrypoint to the application. It performs initialisation and starts the
web server.

### `app/web` module

This module contains the application's middleware stack and any custom types,
middleware, and other functions that are used by the request handlers.

### `app/router` module

This module contains the application's request handlers. Or "handler" in this
case, as there's only one!

### `app_test` module

The tests for the application.
