import app/metrics.{create_standard_metrics}
import app/router
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() {
  gleeunit.main()
}

pub fn metrics_test() {
  create_standard_metrics()

  [
    testing.get("/", []),
    testing.get("/", []),
    testing.get("/comments", []),
    testing.get("/comments/1", []),
    testing.get("/comments/2", []),
    testing.get("/comments/3", []),
  ]
  |> list.each(router.handle_request)

  let response = router.handle_request(testing.get("/metrics", []))

  response.status |> should.equal(200)

  let body = testing.string_body(response)

  body
  |> string.contains(
    "http_request_duration_seconds_count{method=\"GET\",route=\"/\",status=\"200\"} 2",
  )
  |> should.be_true

  body
  |> string.contains(
    "http_request_duration_seconds_count{method=\"GET\",route=\"/comments\",status=\"200\"} 1",
  )
  |> should.be_true

  body
  |> string.contains(
    "http_request_duration_seconds_count{method=\"GET\",route=\"/comments:id\",status=\"200\"} 3",
  )
  |> should.be_true
}
