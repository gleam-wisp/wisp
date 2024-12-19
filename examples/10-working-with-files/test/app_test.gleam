import app/router
import gleam/string
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn home_test() {
  let response = router.handle_request(testing.get("/", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([#("content-type", "text/html; charset=utf-8")])

  response
  |> testing.string_body
  |> string.contains("<form method")
  |> should.equal(True)
}

pub fn file_from_disc_test() {
  let response = router.handle_request(testing.get("/file-from-disc", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([
    #("content-type", "text/markdown"),
    #("content-disposition", "attachment; filename=\"hello.md\""),
  ])

  response
  |> testing.string_body
  |> string.starts_with("# Wisp Example: ")
  |> should.equal(True)
}

pub fn file_from_memory_test() {
  let response = router.handle_request(testing.get("/file-from-memory", []))

  response.status
  |> should.equal(200)

  response.headers
  |> should.equal([
    #("content-type", "text/plain"),
    #("content-disposition", "attachment; filename=\"hello.txt\""),
  ])

  response
  |> testing.string_body
  |> should.equal("Hello, Joe!")
}

pub fn upload_file_test() {
  // Oh no! What's this? There's no test here!
  //
  // The helper for constructing a multipart form request in tests has not yet
  // been implemented. If this is something you need for your project, please
  // let us know and we'll bump it up the list of priorities.
  //
  Nil
}
