import app
import app/router
import app/web.{type Context, Context}
import gleam/list
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

fn with_context(testcase: fn(Context) -> t) -> t {
  // Create the context to use in tests
  let context = Context(static_directory: app.static_directory())

  // Run the test with the context
  testcase(context)
}

pub fn get_home_page_test() {
  use ctx <- with_context
  let request = testing.get("/", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])
}

pub fn get_stylesheet_test() {
  use ctx <- with_context
  let request = testing.get("/static/styles.css", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)

  response.headers
  |> list.key_find("content-type")
  |> should.equal(Ok("text/css; charset=utf-8"))
}

pub fn get_javascript_test() {
  use ctx <- with_context
  let request = testing.get("/static/main.js", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)

  response.headers
  |> list.key_find("content-type")
  |> should.equal(Ok("text/javascript; charset=utf-8"))
}
