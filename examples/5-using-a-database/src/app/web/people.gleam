import app/web.{Context}
import gleam/dynamic.{Dynamic}
import gleam/http.{Get, Post}
import gleam/json
import gleam/map
import gleam/result.{try}
import tiny_database
import wisp.{Request, Response}

pub fn all(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list_people(ctx)
    Post -> create_person(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> read_person(ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub type Person {
  Person(name: String, favourite_colour: String)
}

pub fn list_people(ctx: Context) -> Response {
  let result = {
    use ids <- try(tiny_database.list(ctx.db))
    let object =
      json.object([
        #(
          "people",
          json.array(ids, fn(id) { json.object([#("id", json.string(id))]) }),
        ),
      ])
    Ok(json.to_string_builder(object))
  }

  case result {
    Ok(json) -> wisp.json_response(json, 200)
    Error(Nil) -> wisp.internal_server_error()
  }
}

pub fn create_person(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)

  let result = {
    use person <- try(decode_person(json))
    use id <- try(save_to_database(ctx.db, person))
    let object = json.object([#("id", json.string(id))])
    Ok(json.to_string_builder(object))
  }

  case result {
    Ok(json) -> wisp.json_response(json, 201)
    Error(Nil) -> wisp.unprocessable_entity()
  }
}

pub fn read_person(ctx: Context, id: String) -> Response {
  let result = {
    use person <- try(read_from_database(ctx.db, id))
    let object =
      json.object([
        #("id", json.string(id)),
        #("name", json.string(person.name)),
        #("favourite-colour", json.string(person.favourite_colour)),
      ])
    Ok(json.to_string_builder(object))
  }

  case result {
    Ok(json) -> wisp.json_response(json, 201)
    Error(Nil) -> wisp.not_found()
  }
}

fn decode_person(json: Dynamic) -> Result(Person, Nil) {
  let decoder =
    dynamic.decode2(
      Person,
      dynamic.field("name", dynamic.string),
      dynamic.field("favourite-colour", dynamic.string),
    )
  let result = decoder(json)

  // In this example we are not going to be reporting specific errors to the
  // user, so we can discard the error and replace it with Nil.
  result
  |> result.nil_error
}

// TODO: document
pub fn save_to_database(
  db: tiny_database.Connection,
  person: Person,
) -> Result(String, Nil) {
  let data =
    map.from_list([
      #("name", person.name),
      #("favourite-colour", person.favourite_colour),
    ])
  tiny_database.insert(db, data)
}

// TODO: document
pub fn read_from_database(
  db: tiny_database.Connection,
  id: String,
) -> Result(Person, Nil) {
  use data <- try(tiny_database.read(db, id))
  use name <- try(map.get(data, "name"))
  use favourite_colour <- try(map.get(data, "favourite-colour"))
  Ok(Person(name, favourite_colour))
}
