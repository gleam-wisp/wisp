import gleam/dynamic
import ids/nanoid
import sqlight.{SqlightError}

pub type Connection =
  sqlight.Connection

pub type Error {
  ApplicationNotFound
  DatabaseError(sqlight.Error)
  RecordNotFound
  TooManyRecords
  AlreadyAnswered
}

const database_schema = "
create table if not exists applications (
  id text primary key not null
    constraint valid_id check (length(id) > 0)
, created_at text
    default current_timestamp
    constraint valid_created_at check (datetime(created_at) not null)
) strict;

create table if not exists submissions (
  id integer primary key autoincrement not null
, application_id text not null
, step text not null
    constraint valid_step check (length(step) > 0)
, created_at text
    default current_timestamp
    constraint valid_created_at check (datetime(created_at) not null)
, foreign key (application_id) references applications (id)
) strict;

create table if not exists answers (
  id integer primary key autoincrement not null
, submission_id text not null
, created_at text
    default current_timestamp
    constraint valid_created_at check (datetime(created_at) not null)
, question text not null
    constraint valid_question check (length(question) > 0)
, value text not null
    constraint valid_value check (length(value) > 0)
, foreign key (submission_id) references submissions (id)
, unique (submission_id, question)
) strict;
"

pub fn with_connection(path: String, next: fn(sqlight.Connection) -> a) -> a {
  use db <- sqlight.with_connection(path)

  let preamble =
    "
pragma foreign_keys = on;
pragma journal_mode = wal;
"

  // Enable configuration we want for all connections
  let assert Ok(_) = sqlight.exec(preamble, db)

  // Migrate the database
  let assert Ok(_) = sqlight.exec(database_schema, db)

  next(db)
}

fn one(
  database: sqlight.Connection,
  sql: String,
  arguments: List(sqlight.Value),
  decoder: dynamic.Decoder(a),
) -> Result(a, Error) {
  case sqlight.query(sql, database, arguments, decoder) {
    Ok([]) -> Error(RecordNotFound)
    Ok([x]) -> Ok(x)
    Ok(_) -> Error(TooManyRecords)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn create_application(database: sqlight.Connection) -> String {
  let id = nanoid.generate()
  let sql =
    "
  insert into applications 
    (id)
  values 
    (?)
  "
  let arguments = [sqlight.text(id)]
  let assert Ok(_) = sqlight.query(sql, database, arguments, Ok)
  id
}

pub fn create_submission(
  database: sqlight.Connection,
  application_id application_id: String,
  step_name step_name: String,
) -> Int {
  let sql =
    "
  insert into submissions 
    (application_id, step)
  values 
    (?, ?)
  returning
    id
  "
  let arguments = [sqlight.text(application_id), sqlight.text(step_name)]
  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(id) = one(database, sql, arguments, decoder)
  id
}

pub fn record_answer(
  database database: sqlight.Connection,
  submission_id submission_id: Int,
  question question: String,
  answer answer: String,
) -> Result(Nil, Error) {
  let sql =
    "
  insert into answers 
    (submission_id, question, value)
  values 
    (?, ?, ?)
  "
  let arguments = [
    sqlight.int(submission_id),
    sqlight.text(question),
    sqlight.text(answer),
  ]
  case sqlight.query(sql, database, arguments, Ok) {
    Ok(_) -> Ok(Nil)
    Error(SqlightError(sqlight.ConstraintUnique, _, _)) ->
      Error(AlreadyAnswered)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub type Answer {
  Answer(created_at: String, question: String, value: String)
}

pub fn list_answers(
  database database: sqlight.Connection,
  application_id application_id: String,
) -> List(Answer) {
  let sql =
    "
  select
    answers.created_at, question, value
  from
    answers
  join
    submissions on answers.submission_id = submissions.id
  where
    application_id = ?
  order by
    answers.id asc
  "
  let arguments = [sqlight.text(application_id)]
  let decoder =
    dynamic.decode3(
      Answer,
      dynamic.element(0, dynamic.string),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, dynamic.string),
    )
  let assert Ok(rows) = sqlight.query(sql, database, arguments, decoder)
  rows
}
