# Wisp Example: Working with form data

```sh
gleam run -m working_with_form_data/app  # Run the server
```

This example shows how to read urlencoded and multipart formdata from a request

This example is based off of the ["Hello, World!" example][hello], and uses
concepts from the [routing example][routing] so read those first. The additions
are detailed here and commented in the code.

[hello]: [examples/src/hello_world](./../hello_world/)
[routing]: [examples/src/hello_world](./../routing/)

### `app/router` module

The `handle_request` function has been updated to read the form data from the
request body and make use of values from it.

### Unit tests [examples/test/working_with_form_data/](../../test/working_with_form_data/)

Tests have been added that send requests with form data bodies and check that
the expected response is returned.

### Other files

No changes have been made to the other files.
