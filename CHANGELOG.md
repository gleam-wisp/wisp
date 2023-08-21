# Changelog

## v0.4.0 - Unreleased

- The `wisp` module gains the `json_body`, `require_json` and `require_content_type`
  functions.
- The `wisp/testing` module gains the `post_json`, `put_json`, `patch_json`, and
  `delete_json` functions.
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
