import htmb
import gleam/string_builder

pub type Html =
  htmb.Html

pub type StringBuilder =
  string_builder.StringBuilder

pub const h = htmb.h

pub const text = htmb.text

pub fn page(html: Html) -> StringBuilder {
  let viewport = [
    #("name", "viewport"),
    #("content", "width=device-width, initial-scale=1"),
  ]

  h(
    "html",
    [#("lang", "en")],
    [
      h(
        "head",
        [],
        [h("meta", [#("charset", "utf-8")], []), h("meta", viewport, [])],
      ),
      h("body", [], [html]),
    ],
  )
  |> htmb.render_page(doctype: "html")
}
