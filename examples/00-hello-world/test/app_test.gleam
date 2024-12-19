import app/router
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn hello_world_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  response
  |> testing.string_body
  |> should.equal("<h1>Hello, Joe!</h1>")
}
