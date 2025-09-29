import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/result.{try}
import tiny_database
import using_a_database/app/web.{type Context}
import wisp.{type Request, type Response}

// This request handler is used for requests to `/people`.
//
pub fn all(req: Request, ctx: Context) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> list_people(ctx)
    Post -> create_person(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// This request handler is used for requests to `/people/:id`.
//
pub fn one(req: Request, ctx: Context, id: String) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> read_person(ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub type Person {
  Person(name: String, favourite_colour: String)
}

// This handler returns a list of all the people in the database, in JSON
// format.
//
pub fn list_people(ctx: Context) -> Response {
  let result = {
    // Get all the ids from the database.
    use ids <- try(tiny_database.list(ctx.db))

    // Convert the ids into a JSON array of objects.
    Ok(
      json.to_string(
        json.object([
          #(
            "people",
            json.array(ids, fn(id) { json.object([#("id", json.string(id))]) }),
          ),
        ]),
      ),
    )
  }

  case result {
    // When everything goes well we return a 200 response with the JSON.
    Ok(json) -> wisp.json_response(json, 200)

    // In a later example we will see how to return specific errors to the user
    // depending on what went wrong. For now we will just return a 500 error.
    Error(Nil) -> wisp.internal_server_error()
  }
}

pub fn create_person(req: Request, ctx: Context) -> Response {
  // Read the JSON from the request body.
  use json <- wisp.require_json(req)

  let result = {
    // Decode the JSON into a Person record.
    // In a real application we wouldn't throw away the errors.
    use person <- try(
      decode.run(json, person_decoder())
      |> result.replace_error(Nil),
    )

    // Save the person to the database.
    use id <- try(save_to_database(ctx.db, person))

    // Construct a JSON payload with the id of the newly created person.
    Ok(json.to_string(json.object([#("id", json.string(id))])))
  }

  // Return an appropriate response depending on whether everything went well or
  // if there was an error.
  case result {
    Ok(json) -> wisp.json_response(json, 201)
    Error(Nil) -> wisp.unprocessable_content()
  }
}

pub fn read_person(ctx: Context, id: String) -> Response {
  let result = {
    // Read the person with the given id from the database.
    use person <- try(read_from_database(ctx.db, id))

    // Construct a JSON payload with the person's details.
    Ok(
      json.to_string(
        json.object([
          #("id", json.string(id)),
          #("name", json.string(person.name)),
          #("favourite-colour", json.string(person.favourite_colour)),
        ]),
      ),
    )
  }

  // Return an appropriate response.
  case result {
    Ok(json) -> wisp.json_response(json, 200)
    Error(Nil) -> wisp.not_found()
  }
}

fn person_decoder() -> decode.Decoder(Person) {
  use name <- decode.field("name", decode.string)
  use favourite_colour <- decode.field("favourite-colour", decode.string)
  decode.success(Person(name:, favourite_colour:))
}

/// Save a person to the database and return the id of the newly created record.
pub fn save_to_database(
  db: tiny_database.Connection,
  person: Person,
) -> Result(String, Nil) {
  // In a real application you might use a database client with some SQL here.
  // Instead we create a simple dict and save that.
  let data =
    dict.from_list([
      #("name", person.name),
      #("favourite-colour", person.favourite_colour),
    ])
  tiny_database.insert(db, data)
}

pub fn read_from_database(
  db: tiny_database.Connection,
  id: String,
) -> Result(Person, Nil) {
  // In a real application you might use a database client with some SQL here.
  use data <- try(tiny_database.read(db, id))
  use name <- try(dict.get(data, "name"))
  use favourite_colour <- try(dict.get(data, "favourite-colour"))
  Ok(Person(name, favourite_colour))
}
