import app/web
import gleam/http.{Delete, Get, Post}
import gleam/list
import gleam/result
import gleam/crypto
import gleam/bit_string
import gleam/string_builder
import wisp.{Request, Response}

const cookie_name = "id"

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> home(req)
    ["session"] -> session(req)
    _ -> wisp.not_found()
  }
}

pub fn home(req: Request) -> Response {
  case get_name_from_signed_cookie(req) {
    Ok(name) -> {
      [
        "<h1>Hello, " <> wisp.escape_html(name) <> "!</h1>",
        "<form action='/session?_method=DELETE' method='post'>",
        "  <button type='submit'>Log out</button>",
        "</form>",
      ]
      |> string_builder.from_strings
      |> wisp.html_response(200)
    }
    Error(_) -> {
      wisp.redirect("/session")
    }
  }
}

pub fn get_name_from_signed_cookie(req: Request) -> Result(String, Nil) {
  req
  |> wisp.get_cookie(cookie_name)
  |> result.try(wisp.verify_signed_message(req, _))
  |> result.try(bit_string.to_string)
}

pub fn session(req: Request) -> Response {
  case req.method {
    Get -> new_session()
    Post -> create_session(req)
    Delete -> destroy_session(req)
    _ -> wisp.method_not_allowed([Get, Post, Delete])
  }
}

pub fn new_session() -> Response {
  "
  <form action='/session' method='post'>
    <label>
      Name: <input type='text' name='name'>
    </label>
    <button type='submit'>Log in</button>
  </form>
  "
  |> string_builder.from_string
  |> wisp.html_response(200)
}

pub fn destroy_session(req: Request) -> Response {
  let response = wisp.redirect("/session")
  case wisp.get_cookie(req, cookie_name) {
    Ok(value) -> wisp.set_cookie(response, cookie_name, value, max_age: 0)
    Error(_) -> response
  }
}

pub fn create_session(req: Request) -> Response {
  use formdata <- wisp.require_form(req)

  let result = {
    use name <- result.try(list.key_find(formdata.values, "name"))
    let bytes = bit_string.from_string(name)
    let signed = wisp.sign_message(req, bytes, crypto.Sha512)
    Ok(signed)
  }

  case result {
    Ok(signed) -> {
      wisp.redirect("/")
      |> wisp.set_cookie(cookie_name, signed, max_age: 60 * 60 * 24)
    }
    Error(_) -> {
      wisp.redirect("/session")
    }
  }
}
