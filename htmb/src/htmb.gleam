//// # HyperText Markup Builder
//// 
//// A tiny and fast HTML builder for Gleam.
//// 
//// ```gleam
//// let html = 
////   h("h1", [], [text("Hello, Joe!")])
////  |> render
////  |> string_builder.to_string
//// assert html == "<h1>Hello, Joe!</h1>"
//// ```
//// 
//// This package doesn't do much. If you'd like more features, check out these
//// alternatives:
//// 
//// - [Glemplate](https://hex.pm/packages/glemplate)
//// - [Lustre](https://hex.pm/packages/lustre)
//// - [Nakai](https://hex.pm/packages/nakai)
//// - [React Gleam](https://hex.pm/packages/react_gleam)
//// 

import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/list

pub type Html

pub fn h(
  tag: String,
  attributes: List(#(String, String)),
  children: List(Html),
) -> Html {
  "<"
  |> string.append(tag)
  |> list.fold(attributes, _, attribute)
  |> string.append(">")
  |> string_builder.from_string
  |> list.fold(children, _, child)
  |> string_builder.append("</" <> tag <> ">")
  |> dangerous_unescaped_fragment
}

pub fn text(content: String) -> Html {
  content
  |> escape("", _)
  |> string_builder.from_string
  |> dangerous_unescaped_fragment
}

pub fn escape(escaped: String, content: String) -> String {
  case string.pop_grapheme(content) {
    Ok(#("<", xs)) -> escape(escaped <> "&lt;", xs)
    Ok(#(">", xs)) -> escape(escaped <> "&gt;", xs)
    Ok(#("&", xs)) -> escape(escaped <> "&amp;", xs)
    Ok(#(x, xs)) -> escape(escaped <> x, xs)
    Error(_) -> escaped <> content
  }
}

pub fn render_page(html: Html, doctype doctype: String) -> StringBuilder {
  render(html)
  |> string_builder.prepend("<!DOCTYPE " <> doctype <> ">")
}

fn attribute(content: String, attribute: #(String, String)) -> String {
  content <> " " <> attribute.0 <> "=\"" <> attribute.1 <> "\""
}

fn child(siblings: StringBuilder, child: Html) -> StringBuilder {
  string_builder.append_builder(siblings, render(child))
}

@external(erlang, "htmb_ffi", "identity")
@external(javascript, "./htmb_ffi.mjs", "identity")
pub fn dangerous_unescaped_fragment(s: StringBuilder) -> Html

@external(erlang, "htmb_ffi", "identity")
@external(javascript, "./htmb_ffi.mjs", "identity")
pub fn render(element: Html) -> StringBuilder
