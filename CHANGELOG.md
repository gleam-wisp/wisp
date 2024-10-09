# Changelog

## v1.2.0 - 2024-10-09

- The requirement for `gleam_json` has been relaxed to < 3.0.0.
- The requirement for `mist` has been relaxed to < 4.0.0.
- The Gleam version requirement has been corrected to `>= 1.1.0` from the
  previously inaccurate `">= 0.32.0`.

## v1.1.0 - 2024-08-23

- Rather than using `/tmp`, the platform-specific temporary directory is
  detected used.

## v1.0.0 - 2024-08-21

- The Mist web server related functions have been moved to the `wisp_mist`
  module.
- The `wisp` module gains the `set_logger_level` function and `LogLevel` type.

## v0.16.0 - 2024-07-13

- HTML and JSON body functions now include `charset=utf-8` in the content-type
  header.
- The `require_content_type` function now handles additional attributes
  correctly.

## v0.15.0 - 2024-05-12

- The `mist` version constraint has been increased to >= 1.2.0.
- The `simplifile` version constraint has been increased to >= 2.0.0.
- The `escape_html` function in the `wisp` module has been optimised.

## v0.14.0 - 2024-03-28

- The `mist` version constraint has been relaxed to permit 0.x or 1.x versions.

## v0.13.0 - 2024-03-23

- The `wisp` module gains the `file_download_from_memory` and `file_download`
  functions.

## v0.12.0 - 2024-02-17

- The output format used by the logger has been improved.
- Erlang SASL and supervisor logs are no longer emitted.

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
