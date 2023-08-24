# Wisp Example: Working with JSON

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to use a database, using a `Context` type to hold the
database connection.

This example is based off of the ["working with JSON" example][json], so read
that first. The additions are detailed here and commented in the code.

[json]: https://github.com/lpil/wisp/tree/main/examples/3-working-with-json

### `gleam.toml` file

The `tiny_database` package has been added as a dependency. In a real project
you would like use a proper database such as Postgres or SQLite.

### `app/web` module

A new `Context` type has been created to hold the database connection.

### `app` module

The `main` function now starts by creating a database connection and passing it
to the handler function in a `Context` record.

### `app/router` module

The `handle_request` function has been updated to route requests to functions in
the new `app/web/people` module.

### `app/web/people` module

This module has been created to hold all the functions for working with the
"people" feature, including their request handlers.

### `app_test` module

The `with_context` function has been added to create a `Context` record with a
database connection, and to setup the database.

The tests have been updated to verify that the application saves and retrieves
the data correctly.

### Other files

No changes have been made to the other files.
