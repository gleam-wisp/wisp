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

The `handle_request` function has been updated to handle multiple routes:
- `GET /people` returns a list of all the entities in the database.
- `POST /people` reads JSON data from the request body and saves it in the database.
- `GET /people/:id` returns the entity with the given id.

### `app/web/people` module

This module has been created to hold all the functions for working with the
"people" resource, including their request handlers.

### `app/test/setup` module

This module has been created with a `with_context` function to create a new
`Context` object for use in tests.

### `app_test` module

The tests have been updated to verify that the application saves and retrieves
the data correctly.

### Other files

No changes have been made to the other files.
