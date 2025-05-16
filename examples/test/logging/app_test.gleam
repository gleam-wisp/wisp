import gleeunit/should
import logging/app/router
import wisp/testing

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request)

  response.status
  |> should.equal(200)
}
