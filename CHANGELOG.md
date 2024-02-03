# Changelog

## v0.11.0 - 2024-02-03

- Updated for simplifile v1.4 and replaced the deprecated `simplifile.is_file`
  function with `simplifile.verify_is_file`.

## v0.10.0 - 2024-01-17

- Relaxed version constraints for `gleam_stdlib` and `gleam_json` to permit 0.x
  or 1.x versions.

## v0.9.0 - 2024-01-15

- Updated for Gleam v0.33.0.
- Updated for simplifile v1.0.

## v0.8.0 - 2023-11-13

- Updated for simplifile v0.3.

## v0.7.0 - 2023-11-05

- Updated for Gleam v0.32. All references to "bit string" have been changed to
  "bit array" to match.
- The `wisp` module gains the `get_query` function.

## v0.6.0 - 2023-10-19

- The `wisp.require_form` now handles `application/x-www-form-urlencoded`
  content types with a charset.

## v0.5.0 - 2023-09-13

- The `wisp` module gains the `set_cookie`, `get_cookie`, `json_response` and
  `priv_directory` functions.
- The `wisp` module gains the `Security` type.

## v0.4.0 - 2023-08-24

- The `wisp` module gains the `set_header`, `string_builder_body`,
  `string_body`, `json_body`, `unprocessable_entity`, `require_json` and
  `require_content_type` functions.
- The `wisp/testing` module gains the `post_json`, `put_json`, `patch_json`,
  `delete_json`, and `set_header` functions.
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
