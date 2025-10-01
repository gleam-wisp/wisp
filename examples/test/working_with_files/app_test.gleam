import gleam/http
import gleam/string
import wisp/simulate
import working_with_files/app/router

pub fn home_test() {
  let response = router.handle_request(simulate.browser_request(http.Get, "/"))

  assert response.status == 200

  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  assert response
    |> simulate.read_body
    |> string.contains("<form method")
    == True
}

pub fn file_from_disc_test() {
  let response =
    router.handle_request(simulate.browser_request(http.Get, "/file-from-disc"))

  assert response.status == 200

  assert response.headers
    == [
      #("content-type", "text/markdown"),
      #("content-disposition", "attachment; filename=\"hello.md\""),
    ]

  assert response
    |> simulate.read_body
    |> string.starts_with("name = \"examples\"")
    == True
}

pub fn file_from_memory_test() {
  let response =
    router.handle_request(simulate.browser_request(
      http.Get,
      "/file-from-memory",
    ))

  assert response.status == 200

  assert response.headers
    == [
      #("content-type", "text/plain"),
      #("content-disposition", "attachment; filename=\"hello.txt\""),
    ]

  assert simulate.read_body(response) == "Hello, Joe!"
}

pub fn upload_file_test() {
  let file =
    simulate.uploaded_text_file("uploaded-file", "test.txt", "Hello, Joe!")
  let request =
    simulate.browser_request(http.Post, "/upload-file")
    |> simulate.multipart_body([], [file])

  let response = router.handle_request(request)

  assert response.status == 200
  assert response.headers == [#("content-type", "text/html; charset=utf-8")]

  let body = simulate.read_body(response)
  assert string.contains(body, "Thank you for your file!")
  assert string.contains(body, "test.txt")
}
