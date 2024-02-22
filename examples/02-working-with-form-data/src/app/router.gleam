import app/web
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import gleam/string_builder
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  // For GET requests, show the form,
  // for POST requests we use the data from the form
  case req.method {
    Get -> show_form()
    Post -> handle_form_submission(req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

pub fn show_form() -> Response {
  // In a larger application a template library or HTML form library might
  // be used here instead of a string literal.
  let html =
    string_builder.from_string(
      "<form method='post'>
        <label>Title:
          <input type='text' name='title'>
        </label>
        <label>Name:
          <input type='text' name='name'>
        </label>
        <input type='submit' value='Submit'>
      </form>",
    )
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn handle_form_submission(req: Request) -> Response {
  // This middleware parses a `wisp.FormData` from the request body.
  // It returns an error response if the body is not valid form data, or
  // if the content-type is not `application/x-www-form-urlencoded` or
  // `multipart/form-data`, or if the body is too large.
  use formdata <- wisp.require_form(req)

  // The list and result module are used here to extract the values from the
  // form data.
  // Alternatively you could also pattern match on the list of values (they are
  // sorted into alphabetical order), or use a HTML form library.
  let result = {
    use title <- result.try(list.key_find(formdata.values, "title"))
    use name <- result.try(list.key_find(formdata.values, "name"))
    let greeting =
      "Hi, " <> wisp.escape_html(title) <> " " <> wisp.escape_html(name) <> "!"
    Ok(greeting)
  }

  // An appropriate response is returned depending on whether the form data
  // could be successfully handled or not.
  case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body(string_builder.from_string(content))
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}
