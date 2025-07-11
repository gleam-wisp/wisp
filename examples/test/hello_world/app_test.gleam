import hello_world/app/router
import wisp/testing

pub fn hello_world_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert testing.string_body(response) == "<h1>Hello, Joe!</h1>"
}
