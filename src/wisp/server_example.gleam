import gleam/otp/supervision
import wisp
import wisp/server

pub fn main() {
  let state = Nil

  let server: supervision.ChildSpecification(server.ServerReference) =
    server.new(initial_data:, prepare_context:, handle_request:)
    |> server.port(3000)
    |> server.bind("0.0.0.0")
    |> server.supervised()
}

fn handle_request(
  request: wisp.Request,
  client: server.ClientInformation,
) -> wisp.Response {
  wisp.ok()
}
