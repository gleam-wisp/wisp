import app/web
import gleam/http.{Post}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gsv
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  // We want to accept only CSV content, so we use this middleware to check the
  // correct content type header is set, and return an error response if not.
  use <- wisp.require_content_type(req, "text/csv")

  // This middleware reads the body of the request and returns it as a string,
  // erroring if the body is not valid UTF-8, or if the body is too large.
  //
  // If you want to get a bit-string and don't need specifically UTF-8 encoded
  // data then the `wisp.require_bit_string_body` middleware can be used
  // instead.
  use body <- wisp.require_string_body(req)

  // Now that we have the body we can parse and process it.
  // In this case we expect it to be a CSV file with a header row, but in your
  // application it could be XML, protobuf, or anything else.
  let result = {
    // The GSV library is used to parse the CSV.
    use rows <- result.try(gsv.to_lists(body) |> result.replace_error(Nil))

    // Get the first row, which is the header row.
    use headers <- result.try(list.first(rows))

    // Define the table we want to send back to the client.
    let table = [
      ["headers", "row-count"],
      [string.join(headers, ","), int.to_string(list.length(rows) - 1)],
    ]

    // Convert the table to CSV.
    let csv = gsv.from_lists(table, ",", gsv.Unix)

    Ok(csv)
  }

  // An appropriate response is returned depending on whether the CSV could be
  // successfully handled or not.
  case result {
    Ok(csv) -> {
      wisp.ok()
      |> wisp.set_header("content-type", "text/csv")
      |> wisp.string_body(csv)
    }

    Error(_error) -> {
      wisp.unprocessable_entity()
    }
  }
}
