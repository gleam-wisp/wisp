import gleam/http
import gleam/otp/supervision
import gleam/string
import wisp
import wisp/server

pub type Argument {
  Argument(assets_directory: String)
}

pub type Context {
  Context(
    assets_directory: String,
    request_id: String,
    client_ip: server.IpAddress,
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

fn make_context(info: server.ClientInformation, argument: Argument) -> Context {
  Context(
    assets_directory: argument.assets_directory,
    request_id: wisp.random_string(16),
    client_ip: info.ip_address,
  )
}

pub fn supervised_application() -> supervision.ChildSpecification(Nil) {
  let argument = Argument(assets_directory: "priv/assets")

  server.advanced(handle_request:, make_context:)
  |> server.port(3000)
  |> server.supervised(argument)
}
