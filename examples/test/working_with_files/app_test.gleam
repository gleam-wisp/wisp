import gleam/string
import wisp/testing
import working_with_files/app/router

pub fn home_test() {
  let response = router.handle_request(testing.get("/", []))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert response
    |> testing.string_body
    |> string.contains("<form method")
    == True
}

pub fn file_from_disc_test() {
  let response = router.handle_request(testing.get("/file-from-disc", []))

  assert response.status == 200

  assert response.headers
    == [
      #("content-type", "text/markdown"),
      #("content-disposition", "attachment; filename=\"hello.md\""),
    ]

  assert response
    |> testing.string_body
    |> string.starts_with("name = \"examples\"")
    == True
}

pub fn file_from_memory_test() {
  let response = router.handle_request(testing.get("/file-from-memory", []))

  assert response.status == 200

  assert response.headers
    == [
      #("content-type", "text/plain"),
      #("content-disposition", "attachment; filename=\"hello.txt\""),
    ]

  assert testing.string_body(response) == "Hello, Joe!"
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
