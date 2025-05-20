# Wisp Example: Logging

```sh
gleam run -m logging/app  # Run the server
```

This example shows how to log messages using the BEAM logger.

This example is based off of the ["routing" example][routing], so read that
one first. The additions are detailed here and commented in the code.

[routing]: [examples/src/hello_world](./../routing/)

### `app/router` module

The `handle_request` function now logs messages depending on the request.

### Other files

No changes have been made to the other files.
