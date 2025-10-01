# Changelog

## Unreleased

- The `multipart_body` function and the `FileUpload` type have been added to
  the `simulate` module.

## v2.0.1 - 2025-09-27

- Fixed warnings with latest stdlib.

## v2.0.0 - 2025-09-04

- The `unprocessable_entity` function has renamed to `unprocessable_content`.
- The `entity_too_large` function has renamed to `content_too_large`.

## v2.0.0-rc1 - 2025-07-24

- `set_cookie` will no longer set the `Secure` cookie attributes for HTTP
  requests that do not have the `x-forwarded-proto` header. This means that
  browsers like Safari, that do not consider `localhost` etc to be a secure
  context, will send Wisp-set cookies during local development.
- The `parse_range_header` function and `Range` type have been added.
- The `serve_static` middleware now respects the `range` header.
- The `wisp/simulate` module replaces the `wisp/testing` module.
- The `create_canned_connection` function has been removed from the public API.
- The `read_body_to_bitstring` function has renamed to `read_body_bits`.
- The `csrf_known_header_protection` middleware has been added.
- The `Text` body type and associated functions now take a `String` rather than
  a `StringTree`.
- The `Empty` response body type has been removed.
- The `moved_permanently` function has been renamed to `permanent_redirect`.
- The `bad_request` function now takes a string as an argument.

## v1.8.0 - 2025-06-20

- Updated for `gleam_erlang` v1.
- Fixed a bug where the `etag` header may not always be set for static assets.

## v1.7.0 - 2025-05-13

- Updated for latest `gleam_stdlib`.

## v1.6.0 - 2025-03-21

- Updated `serve_static` to generate etags for static assets.

## v1.5.3 - 2025-02-06

- Relaxed the `gleam_http` requirement to permit v4.

## v1.5.2 - 2025-02-03

- Updated for `gleam_erlang` v0.34.0.
- The function `wisp.get_cookie` gains function labels for its arguments.

## v1.5.1 - 2025-01-02

- Fixed a bug where Wisp would fail to compile.

## v1.5.0 - 2024-12-28

- `handle_head` no longer sets the body to `Empty`. This is so the webserver can
  get the content-length of the body that would have been set, which may be
  useful to clients.

## v1.4.0 - 2024-12-19

- Updated for `mist` v5.0.0.

## v1.3.0 - 2024-11-21

- Updated for `gleam_stdlib` v0.43.0.

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
