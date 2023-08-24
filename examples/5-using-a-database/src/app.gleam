import gleam/erlang/process
import tiny_database
import mist
import wisp
import app/router
import app/web

pub const data_directory = "tmp/data"

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // TODO: document
  use db <- tiny_database.with_connection(data_directory)

  // TODO: document
  let context = web.Context(db: db)

  // TODO: document
  let assert Ok(_) =
    router.handle_request(_, context)
    |> wisp.mist_handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
