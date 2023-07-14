import gleeunit
import gleeunit/should
import htmb.{h, render, text}
import gleam/string_builder
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

pub fn hello_joe_test() {
  h("h1", [], [text("Hello Joe!")])
  |> render(None)
  |> string_builder.to_string
  |> should.equal("<h1>Hello Joe!</h1>")
}

pub fn page_test() {
  h(
    "html",
    [#("lang", "en")],
    [
      h(
        "head",
        [],
        [
          h("title", [], [text("htmb test")]),
          h("meta", [#("charset", "utf-8")], []),
        ],
      ),
      h(
        "body",
        [],
        [
          h("h1", [], [text("Hello, Joe!")]),
          h("script", [], [text("console.log('Hello, Joe!');")]),
        ],
      ),
    ],
  )
  |> render(Some("html"))
  |> string_builder.to_string
  |> should.equal(
    "<!DOCTYPE html><html lang=\"en\"><head><title>htmb test</title><meta charset=\"utf-8\"></meta></head><body><h1>Hello, Joe!</h1><script>console.log('Hello, Joe!');</script></body></html>",
  )
}

pub fn escaping_test() {
  h("h1", [], [text("<script>alert('&');</script>")])
  |> render(None)
  |> string_builder.to_string
  |> should.equal("<h1>&lt;script&gt;alert('&amp;');&lt;/script&gt;</h1>")
}
