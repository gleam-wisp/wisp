// TODO: Sign the application id so that bad actors can't generate them.

import action/database
import action/html.{Html, h, text}
import action/web.{Context}
import framework.{Request, Response}
import gleam/list
// TODO: import from framework once we have constructor re-exports
import gleam/http.{Get, Patch}

pub type Step {
  Step(id: String, questions: List(Question))
}

pub type Question {
  Question(text: String, inputs: List(Input))
}

pub type Input {
  Input(name: String, kind: InputKind)
}

pub type InputKind {
  Checkbox(text: String)
  Submit(text: String, value: String)
  Text(required: Bool)
  Email(required: Bool)
  Phone(required: Bool)
  Radio(required: Bool, options: List(String))
}

pub const region_options = ["London", "etc"]

pub const step_initial = Step(
  "intro",
  [
    Question(
      "Are you ready to take action?",
      [
        Input("ready", Submit("I'm ready", "yes")),
        Input("ready", Submit("Not yet", "no")),
      ],
    ),
  ],
)

pub const step_not_ready = Step(
  "not_ready",
  [
    Question(
      "What do you need to take part?",
      [
        Input("logistics", Checkbox("I need help getting to London")),
        Input("logistics", Checkbox("I need help getting to London")),
      ],
    ),
  ],
)

pub const step_ready = Step(
  "ready",
  [
    Question(
      "Have you been trained in non-violent resistance by Just Stop Oil?",
      [
        Input("non-violence-trained", Submit("Yes", "yes")),
        Input("non-violence-trained", Submit("Not yet", "no")),
      ],
    ),
  ],
)

pub const contact_details = Step(
  "contact_details",
  [
    Question("What's your name?", [Input("name", Text(True))]),
    Question("What's your email address?", [Input("email", Email(True))]),
    Question("What's your phone number?", [Input("phone", Phone(True))]),
    Question(
      "What's your region?",
      [Input("region", Radio(True, region_options))],
    ),
  ],
)

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

  step_html(id, step_initial)
  |> html.page
  |> framework.html_response(200)
}

// TODO: implement
// TODO: test
fn update_application(_req: Request, _ctx: Context) -> Response {
  framework.not_found()
}

fn is_submit(input: Input) -> Bool {
  case input.kind {
    Submit(_, _) -> True
    _ -> False
  }
}

fn step_html(application_id: String, step: Step) -> Html {
  let hidden = fn(name, value) {
    let attrs = [#("type", "hidden"), #("name", name), #("value", value)]
    h("input", attrs, [])
  }
  let any_submit =
    step.questions
    |> list.any(fn(question) { list.any(question.inputs, is_submit) })

  let elements = [
    hidden("application_id", application_id),
    hidden("step_id", step.id),
    ..list.map(step.questions, question_html)
  ]
  let elements = case any_submit {
    False ->
      elements
      |> list.append([
        h("input", [#("type", "submit"), #("value", "Submit")], []),
      ])
    True -> elements
  }
  h("form", [#("method", "POST"), #("action", "?_method=PATCH")], elements)
}

fn question_html(question: Question) -> Html {
  h(
    "fieldset",
    [],
    [
      h("legend", [], [text(question.text)]),
      ..list.flat_map(question.inputs, input_html)
    ],
  )
}

fn input_html(input: Input) -> List(Html) {
  let input_element = fn(type_, name, required) {
    let attrs = [#("type", type_), #("name", name), #("id", name)]
    let attrs = case required {
      True -> [#("required", "required"), ..attrs]
      False -> attrs
    }
    [h("input", attrs, [])]
  }

  let name = input.name
  case input.kind {
    Checkbox(text) ->
      list.append(
        input_element("checkbox", name, False),
        [h("label", [#("for", name)], [html.text(text)])],
      )

    Text(required) -> input_element("text", name, required)

    Email(required) -> input_element("email", name, required)

    Phone(required) -> input_element("tel", name, required)

    Submit(text, value) -> {
      let attrs = [
        #("type", "submit"),
        #("value", text),
        #("name", name <> ":" <> value),
      ]
      [h("input", attrs, [])]
    }

    Radio(required, options) -> {
      let option_html = fn(option) {
        let attrs = [
          #("type", "radio"),
          #("name", name),
          #("value", option),
          #("id", name <> ":" <> option),
        ]
        let attrs = case required {
          True -> [#("required", "required"), ..attrs]
          False -> attrs
        }
        let label_attrs = [#("for", name <> ":" <> option)]
        h("label", label_attrs, [h("input", attrs, []), text(option)])
      }
      list.map(options, option_html)
    }
  }
}
