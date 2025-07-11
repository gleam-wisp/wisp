import gleam/http
import gleam/http/request
import gleam/list
import gleam/result
import helper
import wisp
import wisp/simulate

const expected_cookie_value = "123"

fn cookies_handler_with_csrf_protection(
  request: wisp.Request,
  callback: fn() -> t,
) -> wisp.Response {
  use request <- wisp.csrf_known_header_protection(request)
  let cookie = wisp.get_cookie(request, "data", wisp.PlainText)
  callback()
  wisp.ok()
  |> wisp.string_body(cookie |> result.unwrap(""))
}

fn delete_header(request: wisp.Request, name: String) -> wisp.Request {
  request.Request(
    ..request,
    headers: list.filter(request.headers, fn(header) { header.0 != name }),
  )
}

/// Here we are testing that the test helper functions set the appropriate
/// headers for tests to pass when the CSRF protection middlware is in place.
fn send_cookie_request_with_test_helper(method: http.Method) -> wisp.Response {
  let request =
    simulate.browser_request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() { Nil })
}

pub fn test_helper_method_get_test() {
  assert send_cookie_request_with_test_helper(http.Get)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_head_test() {
  assert send_cookie_request_with_test_helper(http.Head)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_post_test() {
  assert send_cookie_request_with_test_helper(http.Post)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_put_test() {
  assert send_cookie_request_with_test_helper(http.Put)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_delete_test() {
  assert send_cookie_request_with_test_helper(http.Delete)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_connect_test() {
  assert send_cookie_request_with_test_helper(http.Connect)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_options_test() {
  assert send_cookie_request_with_test_helper(http.Options)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_trace_test() {
  assert send_cookie_request_with_test_helper(http.Trace)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn test_helper_method_patch_test() {
  assert send_cookie_request_with_test_helper(http.Patch)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

/// Here we are explictly setting the origin and host headers, rather than rely
/// on the test helper. This is to be extra sure the protection is implemented
/// correctly, being as clear as possible.
fn send_cookie_request_with_explicit_matched_origin_header(
  method: http.Method,
) -> wisp.Response {
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
    |> request.set_header("host", "example.com")
    |> request.set_header("origin", "https://example.com")
    |> delete_header("referer")
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() { Nil })
}

pub fn explicitly_matching_origin_method_get_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Get)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_head_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Head)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_post_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Post)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_put_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Put)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_delete_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Delete)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_connect_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Connect)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_options_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Options)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_trace_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Trace)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_origin_method_patch_test() {
  assert send_cookie_request_with_explicit_matched_origin_header(http.Patch)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

/// Here we are explictly setting the referer and host headers, rather than rely
/// on the test helper. This is to be extra sure the protection is implemented
/// correctly, being as clear as possible.
fn send_cookie_request_with_explicit_matched_referer_header(
  method: http.Method,
) -> wisp.Response {
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
    |> request.set_header("host", "example.com")
    |> delete_header("origin")
    |> request.set_header("referer", "https://example.com")
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() { Nil })
}

pub fn explicitly_matching_referer_method_get_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Get)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_head_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Head)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_post_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Post)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_put_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Put)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_delete_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Delete)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_connect_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Connect)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_options_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Options)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_trace_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Trace)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn explicitly_matching_referer_method_patch_test() {
  assert send_cookie_request_with_explicit_matched_referer_header(http.Patch)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

fn send_cookie_request_with_mismatched_origin_header(
  method: http.Method,
  should_pass: Bool,
) -> wisp.Response {
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
    |> request.set_header("host", "one.example.com")
    |> request.set_header("origin", "https://two.example.com")
    |> delete_header("referer")
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() {
    case should_pass {
      True -> Nil
      False -> {
        panic as { http.method_to_string(method) <> " should not run" }
      }
    }
  })
}

pub fn mismatched_origin_headers_method_get_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Get, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn mismatched_origin_headers_method_head_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Head, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn mismatched_origin_headers_method_post_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Post, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_put_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Put, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_delete_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Delete, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_connect_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Connect, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_options_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Options, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_trace_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Trace, False)
    == wisp.bad_request()
}

pub fn mismatched_origin_headers_method_patch_test() {
  assert send_cookie_request_with_mismatched_origin_header(http.Patch, False)
    == wisp.bad_request()
}

fn send_cookie_request_with_mismatched_referer_header(
  method: http.Method,
  should_pass: Bool,
) -> wisp.Response {
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
    |> request.set_header("host", "one.example.com")
    |> delete_header("origin")
    |> request.set_header("referer", "https://two.example.com")
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() {
    case should_pass {
      True -> Nil
      False -> {
        panic as { http.method_to_string(method) <> " should not run" }
      }
    }
  })
}

pub fn mismatched_referer_headers_method_get_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Get, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn mismatched_referer_headers_method_head_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Head, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn mismatched_referer_headers_method_post_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Post, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_put_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Put, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_delete_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Delete, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_connect_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Connect, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_options_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Options, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_trace_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Trace, False)
    == wisp.bad_request()
}

pub fn mismatched_referer_headers_method_patch_test() {
  assert send_cookie_request_with_mismatched_referer_header(http.Patch, False)
    == wisp.bad_request()
}

/// This shouldn't be possible with HTTP1 or HTTP2, but let's test it in case
/// something goes wrong or we end up with HTTP3.
fn send_cookie_request_with_no_host_header(
  method: http.Method,
  should_pass: Bool,
) -> wisp.Response {
  let request =
    simulate.request(http.Get, "/")
    |> simulate.header("cookie", "data=MTIz")
    |> request.set_method(method)
    |> delete_header("host")
    |> request.set_header("origin", "https://two.example.com")
    |> delete_header("referer")
  use <- helper.disable_logger
  cookies_handler_with_csrf_protection(request, fn() {
    case should_pass {
      True -> Nil
      False -> {
        panic as { http.method_to_string(method) <> " should not run" }
      }
    }
  })
}

pub fn missing_host_header_method_get_test() {
  assert send_cookie_request_with_no_host_header(http.Get, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn missing_host_header_method_head_test() {
  assert send_cookie_request_with_no_host_header(http.Head, True)
    == wisp.ok() |> wisp.string_body(expected_cookie_value)
}

pub fn missing_host_header_method_post_test() {
  assert send_cookie_request_with_no_host_header(http.Post, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_put_test() {
  assert send_cookie_request_with_no_host_header(http.Put, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_delete_test() {
  assert send_cookie_request_with_no_host_header(http.Delete, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_connect_test() {
  assert send_cookie_request_with_no_host_header(http.Connect, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_options_test() {
  assert send_cookie_request_with_no_host_header(http.Options, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_trace_test() {
  assert send_cookie_request_with_no_host_header(http.Trace, False)
    == wisp.bad_request()
}

pub fn missing_host_header_method_patch_test() {
  assert send_cookie_request_with_no_host_header(http.Patch, False)
    == wisp.bad_request()
}
