# Wisp Example: Working with cookies

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to read and write cookies, and how to sign cookies so
they cannot be tampered with.

This example is based off of the [working with form data example][form-data] so read that one
first. The additions are detailed here and commented in the code.

Signing of cookies uses the `secret_key_base` value. If this value changes then
the application will not be able to verify previously signed cookies, and if
someone gains access to the secret key they will be able to forge cookies. This
example application generates a random string in `app.gleam`, but in a real
application you will need to read this secret value from somewhere secure.

[routing]: https://github.com/lpil/wisp/tree/main/examples/2-working-with-form-data

### `app/router` module

The `handle_request` function has been updated to read and write cookies.

### `app_test` module

Tests have been added to test that cookies are handled correctly, and to create signed cookies for test requests.

### Other files

No changes have been made to the other files.
