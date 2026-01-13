import gleam/otp/supervision
import wisp

pub opaque type Configuration(context) {
  Configuration(
    port: Int,
    bind: String,
    handler: fn(wisp.Request, context) -> wisp.Response,
    init: fn(ClientInformation) -> context,
  )
}

pub type ClientInformation {
  RequestInformation(ip_address: IpAddress)
}

pub opaque type ServerReference {
  ServerReference
}

pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}

pub fn new(
  handler: fn(wisp.Request, ClientInformation) -> wisp.Response,
) -> Configuration(context) {
  Configuration(handler:, port: 3000, bind: "localhost")
}

pub fn port(builder: Configuration, port: Int) -> Configuration {
  Configuration(..builder, port:)
}

pub fn bind(builder: Configuration, bind: String) -> Configuration {
  Configuration(..builder, bind:)
}

pub fn supervised(
  configuration: Configuration,
) -> supervision.ChildSpecification(ServerReference) {
  todo
}
