import action/applications/form.{
  Answer, BoolAnswer, BoolSubmitButtons, Checkboxes, Email, MultipleChoiceAnswer,
  NoAnswer, Phone, Question, Radio, Text, TextAnswer,
}
import gleeunit/should

pub fn text_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Text(required: False),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "wobble")])
  |> should.equal(Ok(Answer(name: "wibble", value: TextAnswer("wobble"))))
}

pub fn text_optional_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Text(required: False),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Ok(Answer(name: "wibble", value: NoAnswer)))
}

pub fn text_required_test() {
  Question(name: "wibble", text: "Wibble, wobble?", input: Text(required: True))
  |> form.answer([#("doo", "bah")])
  |> should.equal(Error("\"Wibble, wobble?\" is required"))
}

pub fn email_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Email(required: False),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "wobble@example.com")])
  |> should.equal(Ok(Answer(
    name: "wibble",
    value: TextAnswer("wobble@example.com"),
  )))
}

pub fn email_trimming_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Email(required: False),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "  wobble@example.com ")])
  |> should.equal(Ok(Answer(
    name: "wibble",
    value: TextAnswer("wobble@example.com"),
  )))
}

pub fn email_invalid_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Email(required: False),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "wobble")])
  |> should.equal(Error("\"wobble\" is not a valid email address"))
}

pub fn email_optional_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Email(required: False),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Ok(Answer(name: "wibble", value: NoAnswer)))
}

pub fn email_required_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Email(required: True),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Error("\"Wibble, wobble?\" is required"))
}

pub fn phone_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: False),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "071234567890")])
  |> should.equal(Ok(Answer(name: "wibble", value: TextAnswer("071234567890"))))
}

pub fn phone_trim_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: False),
  )
  |> form.answer([#("wibble", " +447123 4567890 ")])
  |> should.equal(Ok(Answer(name: "wibble", value: TextAnswer("+4471234567890"))))
}

pub fn phone_too_short_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: False),
  )
  |> form.answer([#("wibble", "4567890 ")])
  |> should.equal(Error("\"4567890\" is not a valid phone number"))
}

pub fn phone_not_numbers_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: False),
  )
  |> form.answer([#("wibble", "wibblewobblewoo")])
  |> should.equal(Error("\"wibblewobblewoo\" is not a valid phone number"))
}

pub fn phone_optional_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: False),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Ok(Answer(name: "wibble", value: NoAnswer)))
}

pub fn phone_required_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Phone(required: True),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Error("\"Wibble, wobble?\" is required"))
}

pub fn bool_submit_buttons_true_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: BoolSubmitButtons("yee", "nah"),
  )
  |> form.answer([#("doo", "bah"), #("wibble:1", "yee")])
  |> should.equal(Ok(Answer(name: "wibble", value: BoolAnswer(True))))
}

pub fn bool_submit_buttons_false_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: BoolSubmitButtons("yee", "nah"),
  )
  |> form.answer([#("doo", "bah"), #("wibble:0", "nah")])
  |> should.equal(Ok(Answer(name: "wibble", value: BoolAnswer(False))))
}

pub fn bool_submit_buttons_required_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: BoolSubmitButtons("yee", "nah"),
  )
  |> form.answer([#("doo", "bah"), #("wibble:2", "?")])
  |> should.equal(Error("\"Wibble, wobble?\" is required"))
}

pub fn checkboxes_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Checkboxes([#("one", "One"), #("two", "Two"), #("three", "Three")]),
  )
  |> form.answer([
    #("doo", "bah"),
    #("wibble:two", "on"),
    #("wibble:three", "on"),
    #("wibble:unknown-other", "on"),
  ])
  |> should.equal(Ok(Answer(
    name: "wibble",
    value: MultipleChoiceAnswer(["two", "three"]),
  )))
}

pub fn checkboxes_none_selected_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Checkboxes([#("one", "One"), #("two", "Two"), #("three", "Three")]),
  )
  |> form.answer([#("doo", "bah"), #("wibble:unknown-other", "on")])
  |> should.equal(Ok(Answer(name: "wibble", value: NoAnswer)))
}

// Radio,

pub fn radio_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Radio(
      required: False,
      options: [#("one", "One"), #("two", "Two"), #("three", "Three")],
    ),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "two")])
  |> should.equal(Ok(Answer(name: "wibble", value: TextAnswer("two"))))
}

pub fn radio_optional_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Radio(
      required: False,
      options: [#("one", "One"), #("two", "Two"), #("three", "Three")],
    ),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Ok(Answer(name: "wibble", value: NoAnswer)))
}

pub fn radio_required_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Radio(
      required: True,
      options: [#("one", "One"), #("two", "Two"), #("three", "Three")],
    ),
  )
  |> form.answer([#("doo", "bah")])
  |> should.equal(Error("\"Wibble, wobble?\" is required"))
}

pub fn radio_invalid_test() {
  Question(
    name: "wibble",
    text: "Wibble, wobble?",
    input: Radio(
      required: True,
      options: [#("one", "One"), #("two", "Two"), #("three", "Three")],
    ),
  )
  |> form.answer([#("doo", "bah"), #("wibble", "unknown")])
  |> should.equal(Error("\"Wibble, wobble?\" was not valid"))
}
