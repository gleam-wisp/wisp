import exception
import wisp

pub fn disable_logger(f: fn() -> t) -> t {
  wisp.set_logger_level(wisp.CriticalLevel)
  use <- exception.defer(fn() { wisp.set_logger_level(wisp.InfoLevel) })
  f()
}
