import gleam/http
import wisp/simulate
import working_with_websockets/app/router

pub fn get_home_page_test() {
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request)

  assert response.status == 200
  assert response.headers == [#("content-type", "text/html; charset=utf-8")]
}

pub fn page_not_found_test() {
  let request = simulate.browser_request(http.Get, "/nothing-here")
  let response = router.handle_request(request)

  assert response.status == 404
}
