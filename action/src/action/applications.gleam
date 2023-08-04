// TODO: Sign the application id so that bad actors can't generate them.

import action/database
import action/applications/form.{
  BoolSubmitButtons, Checkboxes, Email, Phone, Question, Radio, Step, Text,
}
import action/html
import action/web.{Context}
import framework.{Request, Response}
import gleam/list
import gleam/string
import gleam/result
// TODO: import from framework once we have constructor re-exports
import gleam/http.{Get, Patch}

pub type Next {
  NextStep(Step)
  ThankYou
}

pub const region_options = [#("london", "London"), #("etc", "Etc.")]

pub const step_initial = Step(
  "intro",
  [
    Question(
      text: "Are you ready to take action?",
      name: "ready",
      input: BoolSubmitButtons(true: "I'm ready", false: "Not yet"),
    ),
  ],
)

pub const step_not_ready = Step(
  "not_ready",
  [
    Question(
      text: "What do you need to take part?",
      name: "help_required",
      input: Checkboxes([#("logistics", "I need help getting to London")]),
    ),
  ],
)

pub const step_ready = Step(
  "ready",
  [
    Question(
      text: "Have you been trained in non-violent resistance by Just Stop Oil?",
      name: "non-violence-trained",
      input: BoolSubmitButtons(true: "Yes", false: "Not yet"),
    ),
  ],
)

pub const step_contact_details = Step(
  "contact_details",
  [
    Question(text: "What's your name?", name: "name", input: Text(True)),
    Question(
      text: "What's your email address?",
      name: "email",
      input: Email(True),
    ),
    Question(
      text: "What's your phone number?",
      name: "phone",
      input: Phone(True),
    ),
    Question(
      text: "What's your region?",
      name: "region",
      input: Radio(True, region_options),
    ),
  ],
)

pub const steps = [
  step_initial,
  step_not_ready,
  step_ready,
  step_contact_details,
]

pub fn resource(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> new_application(req, ctx)
    Patch -> update_application(req, ctx)
    _ -> framework.method_not_allowed([Get, Patch])
  }
}

// TODO: test
fn new_application(_req: Request, ctx: Context) -> Response {
  let id = database.create_application(ctx.db)

  form.step_html(id, step_initial)
  |> html.page
  |> framework.html_response(200)
}

// TODO: test
fn update_application(req: Request, ctx: Context) -> Response {
  use formdata <- framework.require_form_urlencoded_body(req)
  use step <- framework.require(find_step(formdata))
  use app <- framework.require(list.key_find(formdata, "application_id"))

  // TODO: report error to the user
  let assert Ok(answers) =
    list.try_map(step.questions, form.answer(_, formdata))
  // TODO: report error to the user
  let assert Ok(_) = save_answers(ctx.db, app, step, answers)

  next(step, answers)
  |> html_page(app)
  |> framework.html_response(200)
}

pub fn next(step: Step, answers: List(form.Answer)) -> Next {
  case step.id {
    "intro" ->
      case find_answer(answers, "ready") {
        form.BoolAnswer(True) -> NextStep(step_ready)
        _ -> NextStep(step_not_ready)
      }

    _ -> NextStep(step_initial)
  }
}

fn find_answer(answers: List(form.Answer), name: String) -> form.AnswerValue {
  list.find(answers, fn(a) { a.name == name })
  |> result.map(fn(a) { a.value })
  |> result.unwrap(form.NoAnswer)
}

fn html_page(next: Next, application_id: String) -> html.StringBuilder {
  case next {
    NextStep(step) -> form.step_html(application_id, step)
    ThankYou -> html.text("Thank you!")
  }
  |> html.page
}

fn find_step(formdata: List(#(String, String))) -> Result(Step, Nil) {
  use step_id <- result.try(list.key_find(formdata, "step_id"))
  list.find(steps, fn(s) { s.id == step_id })
}

fn save_answers(
  db: database.Connection,
  application_id: String,
  step: Step,
  answers: List(form.Answer),
) -> Result(Nil, database.Error) {
  let submission_id = database.create_submission(db, application_id, step.id)
  let insert = fn(_, answer: form.Answer) {
    let value = case answer.value {
      form.BoolAnswer(True) -> "true"
      form.BoolAnswer(False) -> "false"
      form.TextAnswer(text) -> text
      form.MultipleChoiceAnswer(choices) -> string.join(choices, ",")
      form.NoAnswer -> ""
    }
    database.record_answer(db, submission_id, answer.name, value)
  }
  list.try_fold(answers, Nil, insert)
}
