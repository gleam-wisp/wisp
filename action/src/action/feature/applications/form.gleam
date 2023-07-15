import action/html.{Html, h, text}
import gleam/regex
import gleam/result
import gleam/string
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
  Radio(required: Bool, options: List(#(String, String)))
}

pub type Answer {
  Answer(name: String, value: AnswerValue)
}

pub type AnswerValue {
  TextAnswer(String)
  MultipleChoiceAnswer(List(String))
  BoolAnswer(Bool)
  NoAnswer
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
        let name = name <> ":" <> option.0
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
      let option_html = fn(pair) {
        let #(option, text) = pair
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
        h("label", label_attrs, [h("input", attrs, []), html.text(text)])
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

// TODO: test
pub fn answer(
  question: Question,
  formdata: List(#(String, String)),
) -> Result(Answer, String) {
  case question.input {
    Text(required) -> {
      text_answer(question, required, formdata)
    }
    Phone(required) -> {
      phone_answer(question, required, formdata)
    }
    Email(required) -> {
      email_answer(question, required, formdata)
    }
    Checkboxes(options) -> {
      checkboxes_answer(question, options, formdata)
    }
    BoolSubmitButtons(_, _) -> {
      bool_submit_buttons_answer(question, formdata)
    }
    Radio(required, options) -> {
      radio_answer(question, required, options, formdata)
    }
  }
  |> result.map(Answer(question.name, _))
}

fn text_answer(
  question: Question,
  required: Bool,
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  case list.key_find(formdata, question.name) {
    Ok(value) -> Ok(TextAnswer(value))
    _ if required -> required_error(question)
    _ -> Ok(NoAnswer)
  }
}

fn try_map_text_answer(
  value: AnswerValue,
  mapper: fn(String) -> Result(String, String),
) -> Result(AnswerValue, String) {
  case value {
    TextAnswer(value) -> result.map(mapper(value), TextAnswer)
    _ -> Ok(value)
  }
}

fn email_answer(
  question: Question,
  required: Bool,
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  use answer <- result.try(text_answer(question, required, formdata))
  use email <- try_map_text_answer(answer)
  case string.contains(email, "@") {
    True -> Ok(string.trim(email))
    False -> Error("\"" <> email <> "\" is not a valid email address")
  }
}

fn phone_answer(
  question: Question,
  required: Bool,
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  use answer <- result.try(text_answer(question, required, formdata))
  use number <- try_map_text_answer(answer)
  let number = string.replace(in: number, each: " ", with: "")
  let assert Ok(regex) = regex.from_string("^\\+?[0-9]{8,16}$")
  case regex.check(regex, number) {
    True -> Ok(number)
    False -> Error("\"" <> number <> "\" is not a valid phone number")
  }
}

fn checkboxes_answer(
  question: Question,
  options: List(#(String, String)),
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  let make = fn(option: #(String, String)) {
    let name = question.name <> ":" <> option.0
    list.key_find(formdata, name)
    |> result.replace(option.0)
  }
  let answers = list.filter_map(options, make)
  case answers {
    [] -> Ok(NoAnswer)
    _ -> Ok(MultipleChoiceAnswer(answers))
  }
}

pub fn bool_submit_buttons_answer(
  question: Question,
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  let yes_name = question.name <> ":1"
  let no_name = question.name <> ":0"
  let yes = list.key_find(formdata, yes_name)
  let no = list.key_find(formdata, no_name)
  case yes, no {
    Ok(_), _ -> Ok(BoolAnswer(True))
    _, Ok(_) -> Ok(BoolAnswer(False))
    _, _ -> required_error(question)
  }
}

fn radio_answer(
  question: Question,
  required: Bool,
  options: List(#(String, String)),
  formdata: List(#(String, String)),
) -> Result(AnswerValue, String) {
  let value =
    formdata
    |> list.key_find(question.name)
    |> result.unwrap("")

  case list.key_find(options, value) {
    Ok(_) -> Ok(TextAnswer(value))
    _ if value == "" && required -> required_error(question)
    _ if value == "" -> Ok(NoAnswer)
    _ -> Error("\"" <> question.text <> "\" was not valid")
  }
}

fn required_error(question: Question) -> Result(t, String) {
  Error("\"" <> question.text <> "\" is required")
}
