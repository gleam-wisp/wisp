import gleam/erlang/process
import gleam/otp/actor
import wisp/internal/supervisor

pub fn supervisor_test() {
  let subject = process.new_subject()

  let actor = fn(number) {
    actor.new_with_initialiser(100, fn(_) {
      process.send(subject, #(number, process.self()))
      actor.initialised(Nil) |> actor.returning(number + 1) |> Ok
    })
    |> actor.start
  }

  // Children send their name back to the test process during
  // initialisation so that we can tell they (re)started
  let template =
    supervisor.Template(start: actor, child_type: supervisor.Worker(100))

  let assert Ok(_) =
    supervisor.new(fn(children) {
      children
      |> supervisor.child(
        from: template,
        taking: fn(_) { 1 },
        returning: fn(_, data) { data },
      )
      |> supervisor.child(
        from: template,
        taking: fn(state) { state },
        returning: fn(_, data) { data },
      )
      |> supervisor.child(
        from: template,
        taking: fn(state) { state },
        returning: fn(_, data) { data },
      )
    })
    |> supervisor.start

  // Assert children have started
  let assert Ok(#(1, p)) = process.receive(subject, 10)
  let assert Ok(#(2, _)) = process.receive(subject, 10)
  let assert Ok(#(3, _)) = process.receive(subject, 10)
  let assert Error(Nil) = process.receive(subject, 10)

  // Kill first child an assert they all restart
  process.kill(p)
  let assert Ok(#(1, p1)) = process.receive(subject, 10)
  let assert Ok(#(2, p2)) = process.receive(subject, 10)
  let assert Ok(#(3, _)) = process.receive(subject, 10)
  let assert Error(Nil) = process.receive(subject, 10)

  // Kill second child an assert the following children restart
  process.kill(p2)
  let assert Ok(#(2, _)) = process.receive(subject, 10)
  let assert Ok(#(3, _)) = process.receive(subject, 10)
  let assert Error(Nil) = process.receive(subject, 10)
  let assert True = process.is_alive(p1)
}
