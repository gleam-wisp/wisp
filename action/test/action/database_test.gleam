import gleeunit/should
import gleam/string
import gleam/order
import action/database

pub fn application_creation_test() {
  use db <- database.with_connection(":memory:")
  let id1 = database.create_application(db)
  let id2 = database.create_application(db)

  id1
  |> should.not_equal(id2)

  let assert 21 = string.length(id1)
  let assert 21 = string.length(id2)
}

pub fn recording_answers_test() {
  use db <- database.with_connection(":memory:")
  let id = database.create_application(db)
  let assert Ok(_) = database.record_answer(db, id, "Who? What?", "Slim Shadey")
  let assert Ok(_) =
    database.record_answer(db, id, "System still working?", "Seems to be")

  let assert [] = database.list_answers(db, "wibble")

  let assert [one, two] = database.list_answers(db, id)

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

pub fn duplicate_answer_test() {
  use db <- database.with_connection(":memory:")
  let id = database.create_application(db)
  let question = "Who? What?"

  let assert Ok(_) = database.record_answer(db, id, question, "Slim Shadey")
  let assert Ok(_) = database.record_answer(db, id, question, "Dave")

  let assert [one] = database.list_answers(db, id)
  one.question
  |> should.equal("Who? What?")
  one.answer
  |> should.equal("Dave")

  let id2 = database.create_application(db)
  let assert Ok(_) = database.record_answer(db, id2, question, "Another")
  let assert [_] = database.list_answers(db, id)
  let assert [_] = database.list_answers(db, id2)
}
