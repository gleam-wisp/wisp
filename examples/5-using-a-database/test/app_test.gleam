import app
import app/router
import app/web.{Context}
import app/web/people.{Person}
import gleam/json
import gleeunit
import gleeunit/should
import tiny_database
import wisp/testing

pub fn main() {
  gleeunit.main()
}

fn with_context(test: fn(Context) -> t) -> t {
  // Create a new database connection for this test
  use db <- tiny_database.with_connection(app.data_directory)

  // Truncate the database so there is no prexisting data from previous tests
  let assert Ok(_) = tiny_database.truncate(db)
  let context = Context(db: db)

  // Run the test with the context
  test(context)
}

pub fn get_unknown_test() {
  use ctx <- with_context
  let request = testing.get("/", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(404)
}

pub fn list_people_test() {
  use ctx <- with_context

  let response = router.handle_request(testing.get("/people", []), ctx)
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "application/json")])

  // Initially there are no people in the database
  response
  |> testing.string_body
  |> should.equal("{\"people\":[]}")

  // Create a new person
  let assert Ok(id) = people.save_to_database(ctx.db, Person("Jane", "Red"))

  // The id of the new person is listed by the API
  let response = router.handle_request(testing.get("/people", []), ctx)
  response
  |> testing.string_body
  |> should.equal("{\"people\":[{\"id\":\"" <> id <> "\"}]}")
}

pub fn create_person_test() {
  use ctx <- with_context
  let json =
    json.object([
      #("name", json.string("Lucy")),
      #("favourite-colour", json.string("Pink")),
    ])
  let request = testing.post_json("/people", [], json)
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(201)

  // The request created a new person in the database
  let assert Ok([id]) = tiny_database.list(ctx.db)

  response
  |> testing.string_body
  |> should.equal("{\"id\":\"" <> id <> "\"}")
}

pub fn create_person_missing_parameters_test() {
  use ctx <- with_context
  let json = json.object([#("name", json.string("Lucy"))])
  let request = testing.post_json("/people", [], json)
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(422)

  // Nothing was created in the database
  let assert Ok([]) = tiny_database.list(ctx.db)
}

pub fn read_person_test() {
  use ctx <- with_context
  let assert Ok(id) = people.save_to_database(ctx.db, Person("Jane", "Red"))
  let request = testing.get("/people/" <> id, [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)

  response
  |> testing.string_body
  |> should.equal(
    "{\"id\":\"" <> id <> "\",\"name\":\"Jane\",\"favourite-colour\":\"Red\"}",
  )
}
