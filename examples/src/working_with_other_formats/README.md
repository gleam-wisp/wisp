# Wisp Example: Working with other formats

```sh
gleam run -m working_with_other_formats/app  # Run the server
```
This example shows how to read and return formats that do not have special
support in Wisp. In this case we'll use CSV, but the same techniques can be used
for any format.

This example is based off of the ["Hello, World!" example][hello], and uses
concepts from the [routing example][routing] so read those first. The additions
are detailed here and commented in the code.

[hello]: [examples/src/hello_world](./../hello_world/)
[routing]: [examples/src/hello_world](./../routing/)

### [`gleam.toml`](../../gleam.toml) file

The `gsv` CSV package has been added as a dependency.

### `app/router` module

The `handle_request` function has been updated to read a string from the
request body, decode it using the `gsv` library, and return some CSV data
back to the client.

### Unit tests [examples/test/working_with_other_formats/](../../test/working_with_other_formats/)

Tests have been added that send requests with CSV bodies and check that the
expected response is returned.

### Other files

No changes have been made to the other files.
