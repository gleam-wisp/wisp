# Wisp Example: Server Sent Events

```sh
gleam run -m server_sent_events  # Run the server
```

TODO: write description

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

### Unit tests [examples/test/server_sent_events/](../../test/server_sent_events/)

The tests for the application.
