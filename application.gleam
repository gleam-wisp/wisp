// TODO: organise this

import gleam/otp/actor
import process_file
import wisp
import wisp/internal/supervisor

pub opaque type Application {
  Application(handler: fn(wisp.Request) -> wisp.Response)
}

pub fn start(
  handler: fn(wisp.Request) -> wisp.Response,
) -> actor.StartResult(supervisor.Supervisor) {
  let file_manager =
    supervisor.Template(
      start: fn(_) { process_file.start() },
      child_type: supervisor.Worker(shutdown_ms: 2000),
    )

  supervisor.new(fn(children) {
    children
    |> supervisor.child(
      from: file_manager,
      taking: fn(argument) { argument },
      returning: fn(_, file_manager) { file_manager },
    )
  })
  |> supervisor.start
}
