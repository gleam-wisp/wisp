import gleam/otp/supervision
import wisp

pub type Application {
  Application(
    port: Int,
    bind: NetworkInterfaceBinding,
    handler: fn(wisp.Request, ClientData) -> wisp.Response,
  )
}

pub type NetworkInterfaceBinding {
  BindLocal
  BindAll
  Bind(String)
}

pub type ClientData {
  RequestInformation(ip_address: IpAddress)
}

pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}

pub fn new(
  handle_request handler: fn(wisp.Request, ClientData) -> wisp.Response,
) -> Application {
  Application(handler:, port: 3000, bind: BindLocal)
}

pub fn port(builder: Application, port: Int) -> Application {
  Application(..builder, port:)
}

pub fn bind(builder: Application, interface: String) -> Application {
  Application(..builder, bind: Bind(interface))
}

pub fn bind_all(builder: Application) -> Application {
  Application(..builder, bind: BindAll)
}
