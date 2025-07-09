import gleam/erlang/process
import gleam/http.{Get}
import gleam/otp/actor
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

pub fn sse(req) -> Response {
  use <- wisp.require_method(req, Get)
  let handler = wisp.SSEHandler()

  let assert Ok(response) = wisp.sse(req, handler)

  response
}

fn init(subj) {
  let subj = process.new_subject()
  let monitor = process.monitor_process(process.self())
  let selector =
    process.new_selector()
    |> process.selecting(subj, function.identity)
    |> process.selecting_process_down(monitor, Down)
  let repeater =
    repeatedly.call(1000, Nil, fn(_state, _count) {
      let now = system_time(Millisecond)
      process.send(subj, Time(now))
    })
  actor.Ready(EventState(0, repeater), selector)
}

fn loop(message: Event, state: EventState) {
  case message {
    Time(value) -> {
      let event = mist.event(string_builder.from_string(int.to_string(value)))
      case mist.send_event(conn, event) {
        Ok(_) -> {
          logging.log(logging.Info, "Sent event: " <> string.inspect(event))
          actor.continue(EventState(..state, count: state.count + 1))
        }
        Error(_) -> {
          repeatedly.stop(state.repeater)
          actor.Stop(process.Normal)
        }
      }
    }
    Down(_process_down) -> {
      repeatedly.stop(state.repeater)
      actor.Stop(process.Normal)
    }
  }
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
