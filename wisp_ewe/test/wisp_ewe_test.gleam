import ewe
import gleam/http/request
import gleam/httpc
import gleeunit
import wisp
import wisp_ewe

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn handler_test() {
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_started) =
    wisp_ewe.handler(
      fn(_req) {
        wisp.ok()
        |> wisp.string_body("Hello, world!")
      },
      secret_key_base,
    )
    |> ewe.new
    |> ewe.quiet
    |> ewe.listening(port: 8000)
    |> ewe.start

  let assert Ok(req) = request.to("http://localhost:8000")
  let assert Ok(resp) = httpc.send(req)

  assert resp.status == 200
  assert resp.body == "Hello, world!"
}
