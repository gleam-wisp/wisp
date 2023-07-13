import framework.{Context}
import gleam/bit_builder.{BitBuilder}
import gleam/dynamic
import gleam/erlang/process
import gleam/http.{Get, Method}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/io
import gleam/string_builder.{StringBuilder}
import ids/nanoid
import mist
import nakai
import nakai/html
import sqlight

pub type State {
  State(db: sqlight.Connection)
}

pub type Error {
  ApplicationNotFound
  DatabaseError(sqlight.Error)
}

pub fn main() {
  let assert Ok(_) = mist.run_service(8000, app, max_body_limit: 4_000_000)
  io.println("Started listening on http://localhost:8000 ✨")
  process.sleep_forever()
}

pub fn app(request: Request(BitString)) -> Response(BitBuilder) {
  use connection <- with_sqlite_database("db.sqlite")

  let state = State(db: connection)
  let context = Context(request: request, state: state)
  handle_request(context)
  |> response.map(bit_builder.from_string_builder)
}

pub fn handle_request(context: Context(state)) -> Response(StringBuilder) {
  let handler = case request.path_segments(context.request) {
    [] -> home_page
    _ -> fn(_) { not_found() }
  }

  context
  |> handler
  |> response.map(nakai.to_string_builder)
}

pub fn home_page(context: Context(state)) -> Response(html.Node(t)) {
  use <- require_method(context, Get)

  let html =
    html.div(
      [],
      [html.h1_text([], "Hello, Joe!"), html.p_text([], "This is a Gleam app!")],
    )
  response.new(200)
  |> response.set_body(html)
}

pub fn require_method(
  context: Context(state),
  method: Method,
  next: fn() -> Response(html.Node(t)),
) -> Response(html.Node(t)) {
  case context.request.method == method {
    True -> next()
    False -> method_not_allowed()
  }
}

pub fn not_found() -> Response(html.Node(t)) {
  let html = html.div([], [html.h1_text([], "There's nothing here")])
  response.new(404)
  |> response.set_body(html)
}

pub fn method_not_allowed() -> Response(html.Node(t)) {
  let html = html.div([], [html.h1_text([], "There's nothing here")])
  response.new(405)
  |> response.set_body(html)
}

const database_schema = "
create table if not exists applications (
  id text primary key not null
    constraint valid_id check (length(id) > 0)

, created_at text
    constraint valid_created_at check (
      datetime(created_at) not null
    )
) strict;

create table if not exists answers (
  id integer primary key autoincrement not null

, application_id text not null

, created_at text
    constraint valid_created_at check (
      datetime(created_at) not null
    )

, question text not null
    constraint valid_question check (length(question) > 0)

, answer text not null
    constraint valid_answer check (length(answer) > 0)

, foreign key (application_id) references applications (id)

, unique (application_id, question)
) strict;
"

pub fn with_sqlite_database(
  path: String,
  next: fn(sqlight.Connection) -> a,
) -> a {
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

pub fn generate_nanoid() -> String {
  let assert Ok(id) = nanoid.generate()
  id
}

pub fn create_application(database: sqlight.Connection) -> String {
  let id = generate_nanoid()
  let sql =
    "
  insert into applications 
    (id, created_at)
  values 
    (?, datetime('now'))
  "
  let arguments = [sqlight.text(id)]
  let assert Ok(_) = sqlight.query(sql, database, arguments, Ok)
  id
}

pub fn record_answer(
  database database: sqlight.Connection,
  application_id application_id: String,
  question question: String,
  answer answer: String,
) -> Result(Nil, Error) {
  let sql =
    "
  insert into answers 
    (application_id, created_at, question, answer)
  values 
    (?, datetime('now'), ?, ?)
  on conflict (application_id, question)
  do update set
    answer = excluded.answer
  , created_at = excluded.created_at
  "
  let arguments = [
    sqlight.text(application_id),
    sqlight.text(question),
    sqlight.text(answer),
  ]
  case sqlight.query(sql, database, arguments, Ok) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub type Answer {
  Answer(created_at: String, question: String, answer: String)
}

pub fn list_answers(
  database database: sqlight.Connection,
  application_id application_id: String,
) -> List(Answer) {
  let sql =
    "
  select created_at, question, answer
  from
    answers
  where
    application_id = ?
  order by
    created_at asc, id asc
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
