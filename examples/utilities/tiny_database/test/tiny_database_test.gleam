import gleam/dict
import gleeunit
import gleeunit/should
import tiny_database

pub fn main() {
  gleeunit.main()
}

pub fn insert_read_test() {
  let connection = tiny_database.connect("tmp/data")

  let data = dict.from_list([#("name", "Alice"), #("profession", "Programmer")])

  let assert Ok(Nil) = tiny_database.truncate(connection)
  let assert Ok([]) = tiny_database.list(connection)
  let assert Ok(id) = tiny_database.insert(connection, data)

  let assert Ok(read) = tiny_database.read(connection, id)
  read
  |> should.equal(data)

  let assert Ok([single]) = tiny_database.list(connection)
  single
  |> should.equal(id)
}
