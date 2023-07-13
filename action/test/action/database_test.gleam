import gleeunit/should
import gleam/string
import gleam/order
import action

pub fn application_creation_test() {
  use db <- action.with_sqlite_database(":memory:")
  let id1 = action.create_application(db)
  let id2 = action.create_application(db)

  id1
  |> should.not_equal(id2)

  let assert 21 = string.length(id1)
  let assert 21 = string.length(id2)
}

pub fn recording_answers_test() {
  use db <- action.with_sqlite_database(":memory:")
  let id = action.create_application(db)
  let assert Ok(_) =
    action.record_answer(db, id, question: "Who? What?", answer: "Slim Shadey")
  let assert Ok(_) =
    action.record_answer(db, id, "System still working?", "Seems to be")

  let assert [] = action.list_answers(db, "wibble")

  let assert [one, two] = action.list_answers(db, id)
  one.question
  |> should.equal("Who? What?")
  one.answer
  |> should.equal("Slim Shadey")

  two.question
  |> should.equal("System still working?")
  two.answer
  |> should.equal("Seems to be")

  one.created_at
  |> string.compare(two.created_at)
  |> should.not_equal(order.Gt)
}
