import app/router
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request)

  response.status
  |> should.equal(200)
}
