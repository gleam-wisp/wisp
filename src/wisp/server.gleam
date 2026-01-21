import gleam/http/request
import gleam/http/response
import gleam/otp/static_supervisor
import gleam/otp/supervision
import mist
import wisp

pub opaque type Configuration(argument) {
  Configuration(
    port: Int,
    bind: String,
    handler: fn(wisp.Request, ClientInformation, argument) -> wisp.Response,
  )
}

pub type ClientInformation {
  RequestInformation(ip_address: IpAddress)
}

pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}

pub fn simple(
  handle_request handler: fn(wisp.Request, argument) -> wisp.Response,
) -> Configuration(argument) {
  let handler = fn(request, _client_information, context) {
    handler(request, context)
  }
  Configuration(port: 3000, bind: "localhost", handler:)
}

pub fn advanced(
  handle_request handler: fn(wisp.Request, context) -> wisp.Response,
  make_context prepare: fn(ClientInformation, argument) -> context,
) -> Configuration(argument) {
  let handler = fn(request, client_information, argument) {
    let context = prepare(client_information, argument)
    handler(request, context)
  }
  Configuration(port: 3000, bind: "localhost", handler:)
}

pub fn port(
  builder: Configuration(argument),
  port: Int,
) -> Configuration(argument) {
  Configuration(..builder, port:)
}

pub fn bind(
  builder: Configuration(argument),
  bind: String,
) -> Configuration(argument) {
  Configuration(..builder, bind:)
}

pub fn supervised(
  configuration: Configuration(argument),
  argument: argument,
) -> supervision.ChildSpecification(Nil) {
  let server =
    configuration.handler
    |> to_mist_handler(argument)
    |> mist.new
    |> mist.port(configuration.port)
    |> mist.bind(configuration.bind)
    |> mist.supervised

  static_supervisor.new(static_supervisor.RestForOne)
  |> static_supervisor.add(server)
  |> static_supervisor.supervised
  |> supervision.map_data(fn(_) { Nil })
}

fn to_mist_handler(
  handle_request: fn(wisp.Request, ClientInformation, argument) -> wisp.Response,
  argument: argument,
) -> fn(request.Request(mist.Connection)) ->
  response.Response(mist.ResponseData) {
  todo
}
