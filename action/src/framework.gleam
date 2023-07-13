import gleam/http/request.{Request}

pub type Context(state) {
  Context(request: Request(BitString), state: state)
}
