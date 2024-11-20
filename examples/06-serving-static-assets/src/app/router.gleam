import app/web.{type Context}
import gleam/string_tree
import wisp.{type Request, type Response}

const html = "<!DOCTYPE html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <title>Wisp Example</title>
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <link rel=\"stylesheet\" href=\"/static/styles.css\">
  </head>
  <body>
    <script src=\"/static/main.js\"></script>
  </body>
</html>
"

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)
  wisp.html_response(string_tree.from_string(html), 200)
}
