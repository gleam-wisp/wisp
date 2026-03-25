import gleam/result
import gleam/uri
import lustre
import lustre/effect
import lustre/element/html
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Route {
  Home
  Guides
  Guide(slug: String)
  NotFound
}

type Msg {
  OnRouteChange(route: Route)
}

fn init(_args) -> #(Route, effect.Effect(Msg)) {
  let route =
    modem.initial_uri()
    |> result.map(fn(url) { uri.path_segments(url.path) })
    |> fn(path) {
      case path {
        Ok([]) -> Home
        Ok(["guides"]) -> Guides
        Ok(["guides", slug]) -> Guide(slug)
        _ -> NotFound
      }
    }

  #(route, modem.init(on_url_change))
}

fn on_url_change(uri: uri.Uri) -> Msg {
  case uri.path_segments(uri.path) {
    [] -> OnRouteChange(Home)
    ["guides"] -> OnRouteChange(Guides)
    ["guides", slug] -> OnRouteChange(Guide(slug))
    _ -> OnRouteChange(NotFound)
  }
}

fn update(route: Route, msg: Msg) {
  case msg {
    OnRouteChange(route) -> #(route, effect.none())
  }
}

fn view(route: Route) {
  html.div([], [
    html.h1([], [html.text("Hello world!")]),
    html.p([], [
      html.text(case route {
        Home -> "Home"
        Guides -> "Guides"
        Guide(slug:) -> "Guide: " <> slug
        NotFound -> "Not found"
      }),
    ]),
  ])
}
