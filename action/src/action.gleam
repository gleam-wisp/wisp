import gleam/erlang/process
import gleam/http/request.{Request}
import gleam/http/response
import gleam/io
import framework
import mist
import action/database
import action/web.{Context}
import action/router

pub fn main() {
  let assert Ok(_) = mist.run_service(8000, app, max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub fn app(request: Request(BitString)) {
  use db <- database.with_connection("db.sqlite")

  let context = Context(db: db)
  router.handle_request(request, context)
  |> response.map(framework.body_to_bit_builder)
}
