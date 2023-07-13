import gleam/bit_builder.{BitBuilder}
import gleam/erlang/process
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/io
import mist

pub fn main() {
  let assert Ok(_) = mist.run_service(8000, app, max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub type Context(state) {
  Context(request: Request(BitString), state: state)
}

pub fn app(request: Request(BitString)) -> Response(BitBuilder) {
  let context = Context(request: request, state: Nil)
  handle_request(context)
}

pub fn handle_request(context: Context(state)) -> Response(BitBuilder) {
  case request.path_segments(context.request) {
    [] -> home_page()
    _ -> not_found()
  }
}

pub fn home_page() -> Response(BitBuilder) {
  response.new(200)
  |> response.set_body("Hello, Joe!")
  |> response.map(bit_builder.from_string)
}

pub fn not_found() -> Response(BitBuilder) {
  response.new(404)
  |> response.set_body("There's nothing here...")
  |> response.map(bit_builder.from_string)
}
