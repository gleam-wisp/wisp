// TODO: Sign the application id so that bad actors can't generate them.

import action/database
import action/feature/applications/form.{
  BoolSubmitButtons, Checkboxes, Email, Phone, Question, Radio, Step, Text,
}
import action/html
import action/web.{Context}
import framework.{Request, Response}
import gleam/io
import gleam/list
import gleam/result
// TODO: import from framework once we have constructor re-exports
import gleam/http.{Get, Patch}
import gleam/string_builder

const region_options = ["London", "etc"]

const step_initial = Step(
  "intro",
  [
    Question(
      text: "Are you ready to take action?",
      name: "ready",
      input: BoolSubmitButtons(true: "I'm ready", false: "Not yet"),
    ),
  ],
)

const step_not_ready = Step(
  "not_ready",
  [
    Question(
      text: "What do you need to take part?",
      name: "help_required",
      input: Checkboxes([#("logistics", "I need help getting to London")]),
    ),
  ],
)

const step_ready = Step(
  "ready",
  [
    Question(
      text: "Have you been trained in non-violent resistance by Just Stop Oil?",
      name: "non-violence-trained",
      input: BoolSubmitButtons(true: "Yes", false: "Not yet"),
    ),
  ],
)

const step_contact_details = Step(
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

const steps = [step_initial, step_not_ready, step_ready, step_contact_details]

pub fn resource(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> new_application(req, ctx)
    Patch -> update_application(req, ctx)
    _ -> framework.method_not_allowed([Get, Patch])
  }
}

// TODO: implement
// TODO: test
fn new_application(_req: Request, ctx: Context) -> Response {
  let id = database.create_application(ctx.db)

  form.step_html(id, step_initial)
  |> html.page
  |> framework.html_response(200)
}

// TODO: implement
// TODO: test
fn update_application(req: Request, _ctx: Context) -> Response {
  use formdata <- framework.require_form_urlencoded_body(req)
  use step <- framework.require(find_step(formdata))
  io.debug(step)
  io.debug(formdata)

  framework.html_response(string_builder.from_string("ok!!!"), 200)
}

fn find_step(formdata: List(#(String, String))) -> Result(Step, Nil) {
  use step_id <- result.try(list.key_find(formdata, "step_id"))
  list.find(steps, fn(s) { s.id == step_id })
}
