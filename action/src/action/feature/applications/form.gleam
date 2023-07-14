import action/html.{Html, h, text}
import gleam/list

pub type Step {
  Step(id: String, questions: List(Question))
}

pub type Question {
  Question(text: String, name: String, input: Input)
}

pub type Input {
  Checkboxes(options: List(#(String, String)))
  BoolSubmitButtons(true: String, false: String)
  Text(required: Bool)
  Email(required: Bool)
  Phone(required: Bool)
  Radio(required: Bool, options: List(String))
}

fn is_submit(input: Input) -> Bool {
  case input {
    BoolSubmitButtons(_, _) -> True
    _ -> False
  }
}

pub fn input_html(input: Input, name: String) -> List(Html) {
  let input_element = fn(type_, name, required) {
    let attrs = [#("type", type_), #("name", name), #("id", name)]
    let attrs = case required {
      True -> [#("required", "required"), ..attrs]
      False -> attrs
    }
    [h("input", attrs, [])]
  }

  case input {
    Checkboxes(options) -> {
      let make = fn(option: #(String, String)) {
        let name = name <> "|" <> option.0
        list.append(
          input_element("checkbox", name, False),
          [h("label", [#("for", name)], [html.text(option.1)])],
        )
      }
      list.flat_map(options, make)
    }

    Text(required) -> input_element("text", name, required)

    Email(required) -> input_element("email", name, required)

    Phone(required) -> input_element("tel", name, required)

    BoolSubmitButtons(yes, no) -> {
      let attrs = fn(text, value) {
        [#("type", "submit"), #("value", text), #("name", name <> ":" <> value)]
      }
      [h("input", attrs(yes, "1"), []), h("input", attrs(no, "0"), [])]
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

pub fn step_html(application_id: String, step: Step) -> Html {
  let hidden = fn(name, value) {
    let attrs = [#("type", "hidden"), #("name", name), #("value", value)]
    h("input", attrs, [])
  }
  let any_submit = list.any(step.questions, fn(q) { is_submit(q.input) })

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
      ..input_html(question.input, question.name)
    ],
  )
}

pub type Answer {
  Answer(key: String, answer: AnswerValue)
}

pub type AnswerValue {
  TextAnswer(String)
  MultipleChoiceAnswer(List(String))
  BoolAnswer(Bool)
  Blank
}

// TODO: test
pub fn answer(
  question: Question,
  formdata: List(#(String, String)),
) -> Result(Answer, Nil) {
  todo
}
