import gleam/result
import gleam/dynamic
import ids/nanoid
import gleam/json
import gleam/list
import gleam/map.{type Map}
import simplifile

pub opaque type Connection {
  Connection(root: String)
}

pub fn connect(root: String) -> Connection {
  let assert Ok(_) = simplifile.create_directory_all(root)
  Connection(root)
}

pub fn disconnect(_connection: Connection) -> Nil {
  // Here we do nothing, but a real database would close the connection or do
  // some other teardown.
  Nil
}

pub fn with_connection(root: String, f: fn(Connection) -> t) -> t {
  let connection = connect(root)
  let result = f(connection)
  disconnect(connection)
  result
}

pub fn truncate(connection: Connection) -> Result(Nil, Nil) {
  let assert Ok(_) = simplifile.delete(connection.root)
  Ok(Nil)
}

pub fn list(connection: Connection) -> Result(List(String), Nil) {
  let assert Ok(_) = simplifile.create_directory_all(connection.root)
  simplifile.list_contents(connection.root)
  |> result.nil_error
}

pub fn insert(
  connection: Connection,
  values: Map(String, String),
) -> Result(String, Nil) {
  let assert Ok(_) = simplifile.create_directory_all(connection.root)
  let id = nanoid.generate()
  let values =
    values
    |> map.to_list
    |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) })
  let json = json.to_string(json.object(values))
  use _ <- result.try(
    simplifile.write(file_path(connection, id), json)
    |> result.nil_error,
  )
  Ok(id)
}

pub fn read(
  connection: Connection,
  id: String,
) -> Result(Map(String, String), Nil) {
  use data <- result.try(
    simplifile.read(file_path(connection, id))
    |> result.nil_error,
  )

  let decoder = dynamic.map(dynamic.string, dynamic.string)

  use data <- result.try(
    json.decode(data, decoder)
    |> result.nil_error,
  )

  Ok(data)
}

fn file_path(connection: Connection, id: String) -> String {
  connection.root <> "/" <> id
}
