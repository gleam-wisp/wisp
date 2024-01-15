import gleam/dict.{type Dict}
import gleam/erlang/atom.{type Atom}
import gleam/dynamic.{type Dynamic}

pub type LogLevel {
  Emergency
  Alert
  Critical
  Error
  Warning
  Notice
  Info
  Debug
}

type DoNotLeak

pub fn configure_logger() -> Nil {
  update_primary_config(
    dict.from_list([#(atom.create_from_string("level"), dynamic.from(Info))]),
  )
  Nil
}

@external(erlang, "logger", "update_primary_config")
fn update_primary_config(config: Dict(Atom, Dynamic)) -> DoNotLeak

pub fn log(level: LogLevel, message: String) -> Nil {
  erlang_log(level, message)
  Nil
}

@external(erlang, "logger", "log")
fn erlang_log(level: LogLevel, message: String) -> DoNotLeak
