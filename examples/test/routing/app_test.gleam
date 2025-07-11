import routing/app/router
import wisp/testing

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request)

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert testing.string_body(response) == "Hello, Joe!"
}

pub fn post_home_page_test() {
  let request = testing.post("/", [], "a body")
  let response = router.handle_request(request)
  assert response.status == 405
}

pub fn page_not_found_test() {
  let request = testing.get("/nothing-here", [])
  let response = router.handle_request(request)
  assert response.status == 404
}

pub fn get_comments_test() {
  let request = testing.get("/comments", [])
  let response = router.handle_request(request)
  assert response.status == 200
}

pub fn post_comments_test() {
  let request = testing.post("/comments", [], "")
  let response = router.handle_request(request)
  assert response.status == 201
}

pub fn delete_comments_test() {
  let request = testing.delete("/comments", [], "")
  let response = router.handle_request(request)
  assert response.status == 405
}

pub fn get_comment_test() {
  let request = testing.get("/comments/123", [])
  let response = router.handle_request(request)
  assert response.status == 200
  assert testing.string_body(response) == "Comment with id 123"
}

pub fn delete_comment_test() {
  let request = testing.delete("/comments/123", [], "")
  let response = router.handle_request(request)
  assert response.status == 405
}
