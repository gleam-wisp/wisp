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
  let application_id = database.create_application(db)
  let id = database.create_submission(db, application_id, "steppy")
  let assert Ok(_) = database.record_answer(db, id, "Who? What?", "Slim Shadey")
  let assert Ok(_) =
    database.record_answer(db, id, "System still working?", "Seems to be")

  let assert [] = database.list_answers(db, "wibble")

  let assert [one, two] = database.list_answers(db, application_id)

  one.question
  |> should.equal("Who? What?")
  one.value
  |> should.equal("Slim Shadey")

  two.question
  |> should.equal("System still working?")
  two.value
  |> should.equal("Seems to be")

  one.created_at
  |> string.compare(two.created_at)
  |> should.not_equal(order.Gt)
}

pub fn duplicate_answer_test() {
  use db <- database.with_connection(":memory:")
  let application_id = database.create_application(db)
  let id = database.create_submission(db, application_id, "steppy")
  let question = "Who? What?"

  let assert Ok(_) = database.record_answer(db, id, question, "Slim Shadey")
  let assert Error(database.AlreadyAnswered) =
    database.record_answer(db, id, question, "Dave")

  let assert [one] = database.list_answers(db, application_id)
  one.question
  |> should.equal("Who? What?")
  one.value
  |> should.equal("Slim Shadey")

  // The same answer can be recorded for different applications
  let application_id2 = database.create_application(db)
  let id2 = database.create_submission(db, application_id2, "steppy")
  let assert Ok(_) = database.record_answer(db, id2, question, "Another")
  let assert [_] = database.list_answers(db, application_id)
  let assert [_] = database.list_answers(db, application_id2)
}
