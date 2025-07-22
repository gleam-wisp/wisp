import gleam/http
import gleam/list
import serving_static_assets/app
import serving_static_assets/app/router
import serving_static_assets/app/web.{type Context, Context}
import wisp/simulate

fn with_context(testcase: fn(Context) -> t) -> t {
  // Create the context to use in tests
  let context = Context(static_directory: app.static_directory())

  // Run the test with the context
  testcase(context)
}

pub fn get_home_page_test() {
  use ctx <- with_context
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request, ctx)

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]
}

pub fn get_stylesheet_test() {
  use ctx <- with_context
  let request = simulate.browser_request(http.Get, "/static/styles.css")
  let response = router.handle_request(request, ctx)

  assert response.status == 200

  assert list.key_find(response.headers, "content-type")
    == Ok("text/css; charset=utf-8")
}

pub fn get_javascript_test() {
  use ctx <- with_context
  let request = simulate.browser_request(http.Get, "/static/main.js")
  let response = router.handle_request(request, ctx)

  assert response.status == 200

  assert list.key_find(response.headers, "content-type")
    == Ok("text/javascript; charset=utf-8")
}
