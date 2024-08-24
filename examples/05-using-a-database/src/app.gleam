import app/router
import app/web
import gleam/erlang/process
import mist
import tiny_database
import wisp
import wisp/wisp_mist

pub const data_directory = "tmp/data"

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // A database creation is created here, when the program starts.
  // This connection is used by all requests.
  use db <- tiny_database.with_connection(data_directory)

  // A context is constructed to hold the database connection.
  let context = web.Context(db: db)

  // The handle_request function is partially applied with the context to make
  // the request handler function that only takes a request.
  let handler = router.handle_request(_, context)

  let assert Ok(_) =
    fn(req, _) { handler(req) }
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
