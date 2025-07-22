import gleam/http
import logging/app/router
import wisp/simulate

pub fn get_home_page_test() {
  let request = simulate.browser_request(http.Get, "/")
  let response = router.handle_request(request)

  assert response.status == 200
}
