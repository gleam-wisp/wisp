import wisp.{Request, Response}
import gleam/string_builder
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import app/web

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case req.method {
    Get -> show_form()
    Post -> handle_form_submission(req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

pub fn show_form() -> Response {
  let html =
    string_builder.from_string(
      "<form method='post'>
        <label for='name'>Title:
          <input type='text' name='title'>
        </label>
        <label for='name'>Name:
          <input type='text' name='name'>
        </label>
        <input type='submit' value='Submit'>
      </form>",
    )
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn handle_form_submission(req: Request) -> Response {
  use formdata <- wisp.require_form(req)

  case parse_formdata(formdata) {
    Ok(content) -> {
      let html = string_builder.from_string(content)
      wisp.ok()
      |> wisp.html_body(html)
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

fn parse_formdata(formdata: wisp.FormData) -> Result(String, Nil) {
  let values = formdata.values
  use title <- result.try(list.key_find(values, "title"))
  use name <- result.map(list.key_find(values, "name"))

  "Hi, " <> wisp.escape_html(title) <> " " <> wisp.escape_html(name) <> "!"
}
