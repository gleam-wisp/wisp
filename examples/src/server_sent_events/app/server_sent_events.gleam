import gleam/erlang/process
import gleam/http.{Get}
import gleam/option
import gleam/otp/actor
import gleam/string
import gleam/string_tree
import logging
import repeatedly
import wisp.{type Request, type Response}

const index_html = "
<!DOCTYPE html>
<html lang=\"en\">
  <head><title>eventzzz</title></head>
  <body>
    <div id='time'></div>
    <script>
      const clock = document.getElementById(\"time\")
      const eventz = new EventSource(\"/clock\")
      eventz.onmessage = (e) => {
        console.log(\"got a message\", e)
        const theTime = new Date(parseInt(e.data))
        clock.innerText = theTime.toLocaleString()
      }
      eventz.onclose = () => {
        clock.innerText = \"Done!\"
      }
      // This is not 'ideal' but there is no way to close the connection from
      // the server :(
      eventz.onerror = (e) => {
        eventz.close()
      }
    </script>
  </body>
</html>
"

pub fn home_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let html = string_tree.from_string(index_html)
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn sse(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let init = fn(subject) {
    let initialised =
      actor.initialised(wisp.SSEState)
      |> actor.returning(subject)

    Ok(initialised)
  }

  let loop = fn(state: wisp.SSEState, message: wisp.SSEMessage) {
    logging.log(logging.Info, "Sent event: " <> string.inspect(message))
    logging.log(logging.Info, "From state: " <> string.inspect(state))
    actor.continue(state)
  }

  let handler = wisp.SSEHandler(init:, loop:)

  let assert option.Some(sse_enabled) = req.body.sse_enabled

  let response = wisp.sse(sse_enabled, handler)

  response
}

pub type EventState {
  EventState(count: Int, repeater: repeatedly.Repeater(Nil))
}

pub type Event {
  Time(Int)
  Down(process.Down)
}

pub type Unit {
  Millisecond
}

@external(erlang, "erlang", "system_time")
fn system_time(unit: Unit) -> Int
