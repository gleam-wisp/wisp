import gleam/http.{Delete, Get, Post}
import gleam/list
import gleam/string
import wisp.{type Request, type Response}
import working_with_cookies/app/web

const cookie_name = "id"

pub fn handle_request(req: Request) -> Response(_) {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> home(req)
    ["session"] -> session(req)
    _ -> wisp.not_found()
  }
}

pub fn home(req: Request) -> Response(_) {
  case wisp.get_cookie(req, cookie_name, wisp.Signed) {
    Ok(name) -> {
      [
        "<h1>Hello, " <> wisp.escape_html(name) <> "!</h1>",
        "<form action='/session?_method=DELETE' method='post'>",
        "  <button type='submit'>Log out</button>",
        "</form>",
      ]
      |> string.concat
      |> wisp.html_response(200)
    }
    Error(_) -> {
      wisp.redirect("/session")
    }
  }
}

pub fn session(req: Request) -> Response(_) {
  case req.method {
    Get -> new_session()
    Post -> create_session(req)
    Delete -> destroy_session(req)
    _ -> wisp.method_not_allowed([Get, Post, Delete])
  }
}

pub fn new_session() -> Response(_) {
  "
  <form action='/session' method='post'>
    <label>
      Name: <input type='text' name='name'>
    </label>
    <button type='submit'>Log in</button>
  </form>
  "
  |> wisp.html_response(200)
}

pub fn destroy_session(req: Request) -> Response(_) {
  let resp = wisp.redirect("/session")
  case wisp.get_cookie(req, cookie_name, wisp.Signed) {
    Ok(value) -> wisp.set_cookie(resp, req, cookie_name, value, wisp.Signed, 0)
    Error(_) -> resp
  }
}

pub fn create_session(req: Request) -> Response(_) {
  use formdata <- wisp.require_form(req)

  case list.key_find(formdata.values, "name") {
    Ok(name) -> {
      wisp.redirect("/")
      |> wisp.set_cookie(req, cookie_name, name, wisp.Signed, 60 * 60 * 24)
    }
    Error(_) -> {
      wisp.redirect("/session")
    }
  }
}
