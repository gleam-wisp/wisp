import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/otp/actor

/// A reference to the running supervisor. In future this could be used to send
/// commands to the supervisor to perform certain actions, but today no such
/// APIs have been exposed.
///
/// This supervisor wrap Erlang/OTP's `supervisor` module, and as such it does
/// not use subjects for message sending. If it was implemented in Gleam a
/// subject might be used instead of this type.
///
pub opaque type Supervisor {
  SupervisorReference(pid: Pid)
}

pub opaque type Builder {
  Builder(
    // strategy: Strategy,
    // intensity: Int,
    // period: Int,
    // auto_shutdown: AutoShutdown,
    initialise: fn() -> Children,
  )
}

pub type Template(argument, return) {
  Template(
    start: fn(argument) -> actor.StartResult(return),
    argument: argument,
    child_type: ChildType,
  )
}

pub type ChildType {
  /// A worker child has to shut-down within a given amount of time.
  Worker(
    /// The number of milliseconds the child is given to shut down. The
    /// supervisor tells the child process to terminate by calling
    /// `exit(Child,shutdown)` and then wait for an exit signal with reason
    /// shutdown back from the child process. If no exit signal is received
    /// within the specified number of milliseconds, the child process is
    /// unconditionally terminated using `exit(Child,kill)`.
    shutdown_ms: Int,
  )
  Supervisor
}

type ErlangChildSpec

pub opaque type Children {
  Children(specifications: List(ErlangChildSpec))
}

pub fn ready() -> Children {
  Children([])
}

pub fn new(initialise: fn() -> Children) -> Builder {
  todo
}

pub fn start(initialise: fn() -> Children) -> actor.StartResult(Supervisor) {
  todo
}

// Callback used by the Erlang supervisor module.
@internal
pub fn init(initialise: fn() -> Children) -> Result(Dynamic, never) {
  let children = initialise().specifications
  todo
}

// Callback used by the Erlang supervisor module.
@internal
pub fn start_child_callback(
  start: fn() -> Result(actor.Started(anything), actor.StartError),
) -> Result(Pid, actor.StartError) {
  case start() {
    Ok(started) -> Ok(started.pid)
    Error(error) -> Error(error)
  }
}

pub fn add(
  template: Template(argument, return),
  next: fn(return) -> Children,
) -> Children {
  let younger_siblings = next()

  Children([])
}

fn convert_child(
  child: Template(argument, return),
  id: Int,
) -> ErlangChildSpec {
  let mfa = #(
    atom.create("gleam@otp@static_supervisor"),
    atom.create("start_child_callback"),
    [child.start],
  )

  let #(type_, shutdown) = case child.child_type {
    Supervisor -> #(atom.create("supervisor"), make_timeout(-1))
    Worker(ms) -> #(atom.create("worker"), make_timeout(ms))
  }

  make_erlang_child_spec([
    Id(id),
    Start(mfa),
    Restart(child.restart),
    Significant(child.significant),
    Type(type_),
    Shutdown(shutdown),
  ])
}

/// Negative numbers mean an infinite timeout
@external(erlang, "gleam_otp_external", "make_timeout")
fn make_timeout(amount: Int) -> Timeout

type Timeout
