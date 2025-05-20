# Wisp Example: Using a database

```sh
gleam run -m using_a_database/app  # Run the server
```

This example shows how to use a database, using a `Context` type to hold the
database connection.

This example is based off of the ["working with JSON" example][json], so read
that first. The additions are detailed here and commented in the code.

[json]: [examples/src/working_with_json](./../working_with_json/)

### [`gleam.toml`](../../gleam.toml) file

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

### Unit tests [examples/test/using_a_database/](../../test/using_a_database/)

The `with_context` function has been added to create a `Context` record with a
database connection, and to setup the database.

The tests have been updated to verify that the application saves and retrieves
the data correctly.

### Other files

No changes have been made to the other files.
