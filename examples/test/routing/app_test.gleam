import gleam/http
import routing/app/router
import wisp/simulate

pub fn get_home_page_test() {
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request)

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert simulate.read_body(response) == "Hello, Joe!"
}

pub fn post_home_page_test() {
  let request =
    simulate.browser_request(http.Post, "/")
    |> simulate.string_body("a body")
  let response = router.handle_request(request)
  assert response.status == 405
}

pub fn page_not_found_test() {
  let request = simulate.browser_request(http.Get, "/nothing-here")
  let response = router.handle_request(request)
  assert response.status == 404
}

pub fn get_comments_test() {
  let request = simulate.browser_request(http.Get, "/comments")
  let response = router.handle_request(request)
  assert response.status == 200
}

pub fn post_comments_test() {
  let request = simulate.browser_request(http.Post, "/comments")
  let response = router.handle_request(request)
  assert response.status == 201
}

pub fn delete_comments_test() {
  let request = simulate.browser_request(http.Delete, "/comments")
  let response = router.handle_request(request)
  assert response.status == 405
}

pub fn get_comment_test() {
  let request = simulate.browser_request(http.Get, "/comments/123")
  let response = router.handle_request(request)
  assert response.status == 200
  assert simulate.read_body(response) == "Comment with id 123"
}

pub fn delete_comment_test() {
  let request = simulate.browser_request(http.Delete, "/comments/123")
  let response = router.handle_request(request)
  assert response.status == 405
}
