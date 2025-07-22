import gleam/http
import hello_world/app/router
import wisp/simulate

pub fn hello_world_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert simulate.read_body(response) == "<h1>Hello, Joe!</h1>"
}
