import gleam/erlang/process
import gleam/io
import framework
import mist
import action/database
import action/web.{Context}
import action/router

pub fn main() {
  let assert Ok(_) =
    app
    |> framework.mist_service
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub fn app(request: framework.Request) {
  use db <- database.with_connection("db.sqlite3")

  let context = Context(db: db)
  router.handle_request(request, context)
}
