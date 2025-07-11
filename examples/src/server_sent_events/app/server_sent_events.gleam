import gleam/erlang/process
import gleam/http.{Get}
import gleam/int
import gleam/option
import gleam/otp/actor
import gleam/string_tree
import repeatedly
import wisp.{type Request}

const index_html = "
<!DOCTYPE html>
<html lang=\"en\">
  <head><title>ServerSentEvents</title></head>
  <body>
    <div id='time'></div>
    <script>
      const clock = document.getElementById(\"time\")
      const serverSentEvents = new EventSource(\"/sse\")
      serverSentEvents.onmessage = (e) => {
        console.log(\"got a message\", e)
        const theTime = new Date(parseInt(e.data))
        clock.innerText = theTime.toLocaleString()
      }
      serverSentEvents.onclose = () => {
        clock.innerText = \"Done!\"
      }
      // This is not 'ideal' but there is no way to close the connection from
      // the server :(
      serverSentEvents.onerror = (e) => {
        serverSentEvents.close()
      }
    </script>
  </body>
</html>
"

pub fn home_page(req: Request) {
  use <- wisp.require_method(req, Get)

  let html = string_tree.from_string(index_html)
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn sse(req: Request) {
  use <- wisp.require_method(req, Get)

  let init = fn(subject) {
    let repeater =
      repeatedly.call(1000, Nil, fn(_state, _count) {
        process.send(subject, Time(system_time(Millisecond)))
      })

    Ok(actor.initialised(EventState(0, repeater)))
  }

  let loop = fn(state: EventState, message: Event, send) {
    case message {
      Time(time) -> {
        send(wisp.SSEEvent(
          int.to_string(time),
          option.None,
          option.None,
          option.None,
        ))
        actor.continue(state)
      }
      Down(_) -> {
        repeatedly.stop(state.repeater)
        actor.stop()
      }
    }
  }

  let assert Ok(response) = wisp.sse(req, init, loop)

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
