import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/list
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

pub opaque type Builder(state) {
  Builder(
    strategy: Strategy,
    // TODO: rename to `max_restarts`?
    intensity: Int,
    // TODO: rename to `max_seconds`?
    period: Int,
    children: fn() -> Children(state),
  )
}

pub type Template(argument, return) {
  Template(
    start: fn(argument) -> actor.StartResult(return),
    /// Whether the child is a supervisor or not.
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

@internal
pub type ErlangChildSpec

pub opaque type Children(state) {
  Children(next_id: Int, specifications: List(ErlangChildSpec))
}

pub fn new(children: fn(Children(Nil)) -> Children(state)) -> Builder(state) {
  Builder(strategy: RestForOne, intensity: 3, period: 5, children: fn() {
    children(Children(next_id: 1, specifications: []))
  })
}

pub fn child(
  children: Children(state1),
  from template: Template(argument, return),
  taking make_argument: fn(state1) -> argument,
  returning make_new_state: fn(state1, return) -> state2,
) -> Children(state2) {
  let specification =
    convert_child(template, make_argument, make_new_state, children.next_id)
  let specifications = [specification, ..children.specifications]
  Children(next_id: children.next_id + 1, specifications:)
}

pub fn start(
  builder: Builder(state),
) -> Result(actor.Started(Supervisor), actor.StartError) {
  let module = atom.create("wisp@internal@supervisor")
  case erlang_start_link(module, builder) {
    Ok(pid) -> Ok(actor.Started(pid:, data: SupervisorReference(pid)))
    Error(error) -> Error(convert_erlang_start_error(error))
  }
}

@external(erlang, "supervisor", "start_link")
fn erlang_start_link(module: Atom, args: Builder(state)) -> Result(Pid, Dynamic)

// Callback used by the Erlang supervisor module.
@internal
pub fn init(
  builder: Builder(state),
) -> Result(#(ErlangSupervisorFlags, List(ErlangChildSpec)), never) {
  let specifications = builder.children().specifications |> list.reverse
  let flags =
    make_erlang_supervisor_flags([
      Strategy(builder.strategy),
      Intensity(builder.intensity),
      Period(builder.period),
    ])

  // Set the initial state before the creation of the first child.
  process_dictionary_put(GleamSupervisorState(0), Nil)

  Ok(#(flags, specifications))
}

// Callback used by the Erlang supervisor module.
@internal
pub fn start_child_callback(
  child: ChildStartData(state1, state2, argument, return),
) -> Result(Pid, actor.StartError) {
  // Get the supervisor state from the process dictionary. This is either the
  // initial state for the oldest child, or it's the state returned by the
  // previous child for the rest of the children.
  let state = process_dictionary_get(GleamSupervisorState(child.id - 1))

  // Construct the argument from the state, using the child's argument
  // preparation function.
  let argument = child.prepare_argument(state)

  // Start the child.
  case child.start_function(argument) {
    // The child started successfully.
    Ok(actor.Started(pid:, data:)) -> {
      // Construct the new supervisor state and store it in the process
      // dictionary, so it can be used by the next child, if there is one.
      let state = child.update_state(state, data)
      process_dictionary_put(GleamSupervisorState(child.id), state)

      // Return the child's pid to the supervisor for it to supervise.
      Ok(pid)
    }

    // The child failed to start.
    Error(error) -> Error(error)
  }
}

fn convert_child(
  child: Template(argument, return),
  prepare_argument: fn(state1) -> argument,
  update_state: fn(state1, return) -> state2,
  id: Int,
) -> ErlangChildSpec {
  let start_data =
    ChildStartData(
      id:,
      start_function: child.start,
      prepare_argument:,
      update_state:,
    )

  let mfa = #(
    atom.create("wisp@internal@supervisor"),
    atom.create("start_child_callback"),
    [start_data],
  )

  let #(type_, shutdown) = case child.child_type {
    Supervisor -> #(atom.create("supervisor"), make_timeout(-1))
    Worker(ms) -> #(atom.create("worker"), make_timeout(ms))
  }

  make_erlang_child_spec([
    Id(id),
    Start(mfa),
    // Restart(child.restart),
    Type(type_),
    Shutdown(shutdown),
  ])
}

@internal
pub type ChildStartData(state1, state2, argument, return) {
  ChildStartData(
    id: Int,
    start_function: fn(argument) ->
      Result(actor.Started(return), actor.StartError),
    prepare_argument: fn(state1) -> argument,
    update_state: fn(state1, return) -> state2,
  )
}

type ErlangChildSpecProperty(state1, state2, argument, return) {
  Id(Int)
  Start(#(Atom, Atom, List(ChildStartData(state1, state2, argument, return))))
  // Restart(Restart)
  Type(Atom)
  Shutdown(Timeout)
}

type ProcessDictionaryKey {
  GleamSupervisorState(id: Int)
}

@external(erlang, "erlang", "get")
fn process_dictionary_get(key: ProcessDictionaryKey) -> value

@external(erlang, "erlang", "put")
fn process_dictionary_put(key: ProcessDictionaryKey, value: value) -> DoNotLeak

type DoNotLeak

@external(erlang, "maps", "from_list")
fn make_erlang_child_spec(
  properties: List(ErlangChildSpecProperty(state1, state2, argument, return)),
) -> ErlangChildSpec

@external(erlang, "maps", "from_list")
fn make_erlang_supervisor_flags(
  properties: List(ErlangSupervisorFlagsProperty),
) -> ErlangSupervisorFlags

type ErlangSupervisorFlagsProperty {
  Strategy(Strategy)
  Intensity(Int)
  Period(Int)
}

@internal
pub type ErlangSupervisorFlags

/// How the supervisor should react when one of its children terminates.
pub type Strategy {
  /// If one child process terminates and is to be restarted, all other child
  /// processes are terminated and then all child processes are restarted.
  OneForAll

  /// If one child process terminates and is to be restarted, the 'rest' of the
  /// child processes (that is, the child processes after the terminated child
  /// process in the start order) are terminated. Then the terminated child
  /// process and all child processes after it are restarted.
  RestForOne
}

/// Negative numbers mean an infinite timeout
@external(erlang, "gleam_otp_external", "make_timeout")
fn make_timeout(amount: Int) -> Timeout

type Timeout

@external(erlang, "gleam_otp_external", "convert_erlang_start_error")
fn convert_erlang_start_error(dynamic: Dynamic) -> actor.StartError
