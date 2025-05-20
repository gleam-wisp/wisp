# Wisp Example: Working with files

```sh
gleam run -m working_with_files/app  # Run the server
```

This example shows how to accept file uploads and allow users to download files.

This example is based off of the ["working with form data" example][form_data],
so read that first. The additions are detailed here and commented in the code.

[form_data]: [examples/src/working_with_form_data](./../working_with_form_data/)

### `app/router` module

The `handle_request` function has been updated to upload and download files.

### Unit tests [examples/test/working_with_files/](../../test/working_with_files/)

Tests have been added that upload and download files to verify the behaviour.

### Other files

No changes have been made to the other files.
