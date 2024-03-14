# Wisp Example: Working with files

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to accept file uploads and allow users to download files.

This example is based off of the ["working with form data" example][formdata],
so read that first. The additions are detailed here and commented in the code.

[formdata]: https://github.com/lpil/wisp/tree/main/examples/02-working-with-form-data

### `app/router` module

The `handle_request` function has been updated to upload and download files.

### `app_test` module

Tests have been added that upload and download files to verify the behaviour.

### Other files

No changes have been made to the other files.
