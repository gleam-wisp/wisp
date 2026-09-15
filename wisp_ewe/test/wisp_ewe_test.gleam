import ewe
import gleam/http/request
import gleam/httpc
import gleeunit
import wisp
import wisp/server
import wisp_ewe

pub fn main() -> Nil {
  gleeunit.main()
}

import gleam/http
import gleam/otp/supervision
import gleam/string

pub type Argument {
  Argument(assets_directory: String)
}

pub type Context {
  Context(
    assets_directory: String,
    request_id: String,
    client_ip: wisp.IpAddress,
  )
}

fn handle_request(request: wisp.Request, context: Context) -> wisp.Response {
  let body =
    "Hello "
    <> context.request_id
    <> "! You made a "
    <> http.method_to_string(request.method)
    <> " from "
    <> string.inspect(context.client_ip)

  wisp.ok()
  |> wisp.string_body(body)
}

fn make_context(info: wisp.ClientInformation, argument: Argument) -> Context {
  Context(
    assets_directory: argument.assets_directory,
    request_id: wisp.random_string(16),
    client_ip: info.ip_address,
  )
}

pub fn supervised_application() -> supervision.ChildSpecification(Nil) {
  let start_data = StartData(assets_directory: "priv/assets")

  let application = server.simple_application(handle_request:, start_data:)
  let configuration =
    server.configuration()
    |> server.port(3000)

  server.configure(port: 3000)
  |> server.supervised
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
