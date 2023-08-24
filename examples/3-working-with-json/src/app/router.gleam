import app/web
import gleam/dynamic.{Dynamic}
import gleam/http.{Post}
import gleam/json
import gleam/result
import wisp.{Request, Response}

// This type is going to be parsed and decoded from the request body.
pub type Person {
  Person(name: String, is_cool: Bool)
}

// To decode the type we need a dynamic decoder.
// See the standard library documentation for more information on decoding
// dynamic values [1].
//
// [1]: https://hexdocs.pm/gleam_stdlib/gleam/dynamic.html
fn decode_person(json: Dynamic) -> Result(Person, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      Person,
      dynamic.field("name", dynamic.string),
      dynamic.field("is-cool", dynamic.bool),
    )
  decoder(json)
}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  // This middleware parses a `Dynamic` value from the request body.
  // It returns an error response if the body is not valid JSON, or
  // if the content-type is not `application/json`, or if the body
  // is too large.
  use json <- wisp.require_json(req)

  let result = {
    // The dynamic value can be decoded into a `Person` value.
    use person <- result.try(decode_person(json))

    // And then a JSON response can be created from the person.
    let object =
      json.object([
        #("name", json.string(person.name)),
        #("is-cool", json.bool(person.is_cool)),
        #("saved", json.bool(True)),
      ])
    Ok(json.to_string_builder(object))
  }

  // An appropriate response is returned depending on whether the JSON could be
  // successfully handled or not.
  case result {
    Ok(json) -> wisp.json_response(json, 201)

    // In a real application we would probably want to return some JSON error
    // object, but for this example we'll just return an empty response.
    Error(_) -> wisp.unprocessable_entity()
  }
}
