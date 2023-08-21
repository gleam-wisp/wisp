# Changelog

## v0.4.0 - Unreleased

- The request construction functions in the `wisp/testing` module now support
  query strings. e.g. `get("/users?limit=10", [])`.

## v0.3.0 - 2023-08-21

- The `mist_service` function has been renamed to `mist_handler`.
- The `method_not_allowed` function gains the `allowed` label for its argument.
- The `wisp` module gains the `html_escape` function.
- The `wisp/testing` module gains the `post_form`, `put_form`, `patch_form`, and
  `delete_form` functions.

## v0.2.0 - 2023-08-12

- Initial release
