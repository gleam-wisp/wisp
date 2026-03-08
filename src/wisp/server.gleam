import gleam/otp/static_supervisor
import gleam/otp/supervision
import wisp

pub type WebServerAdapter(argument) {
  WebServerAdapter(
    supervision_specification: fn(WebServerConfiguration) ->
      supervision.ChildSpecification(Nil),
  )
}

pub type ApplicationConfiguration(argument) {
  Configuration(
    port: Int,
    bind: String,
    handler: fn(wisp.Request, wisp.ClientInformation, argument) -> wisp.Response,
  )
}

pub type WebServerConfiguration {
  WebServerConfiguration(
    port: Int,
    bind: String,
    handler: fn(wisp.Request, wisp.ClientInformation) -> wisp.Response,
  )
}

pub fn simple(
  handle_request handler: fn(wisp.Request, argument) -> wisp.Response,
) -> ApplicationConfiguration(argument) {
  let handler = fn(request, _client_information, context) {
    handler(request, context)
  }
  Configuration(port: 3000, bind: "localhost", handler:)
}

pub fn advanced(
  handle_request handler: fn(wisp.Request, context) -> wisp.Response,
  make_context prepare: fn(wisp.ClientInformation, argument) -> context,
) -> ApplicationConfiguration(argument) {
  let handler = fn(request, client_information, argument) {
    let context = prepare(client_information, argument)
    handler(request, context)
  }
  Configuration(port: 3000, bind: "localhost", handler:)
}

pub fn port(
  builder: ApplicationConfiguration(argument),
  port: Int,
) -> ApplicationConfiguration(argument) {
  Configuration(..builder, port:)
}

pub fn bind(
  builder: ApplicationConfiguration(argument),
  bind: String,
) -> ApplicationConfiguration(argument) {
  Configuration(..builder, bind:)
}

pub fn supervised(
  configuration: ApplicationConfiguration(argument),
  server adapter: WebServerAdapter(argument),
  argument argument: argument,
) -> supervision.ChildSpecification(Nil) {
  let server =
    adapter.supervision_specification(
      WebServerConfiguration(
        port: configuration.port,
        bind: configuration.bind,
        handler: fn(request, info) {
          configuration.handler(request, info, argument)
        },
      ),
    )

  static_supervisor.new(static_supervisor.RestForOne)
  |> static_supervisor.add(server)
  |> static_supervisor.supervised
  |> supervision.map_data(fn(_) { Nil })
}
