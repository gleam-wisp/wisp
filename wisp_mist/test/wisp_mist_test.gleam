import gleam/http/request
import gleam/httpc
import gleeunit
import mist
import wisp
import wisp_mist

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn mist_adapter_test() {
  let secret_key_base = wisp.random_string(64)
  let handler =
    wisp_mist.handler(
      fn(_) { wisp.ok() |> wisp.string_body("Hello, world!") },
      secret_key_base,
    )

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(8000)
    |> mist.start

  let assert Ok(req) = request.to("http://localhost:8000")
  let assert Ok(res) = httpc.send(req)

  assert res.status == 200
  assert res.body == "Hello, world!"
}
