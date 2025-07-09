import gleam/erlang/process
import gleam/otp/actor
import gleam/string_tree
import logging
import repeatedly

// import gleam/erlang/process
// import gleam/function
import gleam/http.{Get}

// import gleam/http/request
// import gleam/int
// import gleam/otp/actor
// import gleam/string
// import logging
// import repeatedly
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

pub fn sse(req) -> Response {
  use <- wisp.require_method(req, Get)
  let init = fn(a) { init }
  let handler = wisp.SSEHandler(init, loop)

  wisp.sse(handler)
}

fn init(subj) {
  let repeater =
    repeatedly.call(1000, Nil, fn(_state, _count) {
      let now = system_time(Millisecond)
      process.send(subj, Time(now))
    })

  repeater
}

fn loop(message: Event, state: EventState) {
  todo
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
