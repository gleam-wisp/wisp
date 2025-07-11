import logging/app/router
import wisp/testing

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request)

  assert response.status == 200
}
