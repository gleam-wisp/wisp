import gleam/result
import gleam/uri
import lustre
import lustre/attribute.{attribute}
import lustre/effect
import lustre/element/html
import lustre/element/svg
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Route {
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

fn update(_route: Route, msg: Msg) {
  case msg {
    OnRouteChange(route) -> #(route, effect.none())
  }
}

pub fn view(route: Route) {
  let version = "5.4.0"

  html.div([], [
    html.header([attribute.class("site-hero pt-32 pb-20")], [
      html.nav([attribute.class("site-nav")], [
        html.div([attribute.class("container")], [
          html.a([attribute.href("/"), attribute.class("site-logo")], [
            html.div(
              [
                attribute.class(
                  "size-10 rounded-lg border-2 border-dashed border-black",
                ),
              ],
              [],
            ),
          ]),
          html.ul([attribute.class("site-links")], [
            html.li([], [
              html.a([attribute.href("/guides")], [
                guide_icon([attribute.class("size-5")]),
                html.text("Guides"),
              ]),
            ]),
            html.li([], [
              html.a([attribute.href("https://github.com/gleam-wisp/wisp")], [
                source_icon([attribute.class("size-5")]),
                html.text("Source"),
              ]),
            ]),
            html.li([], [
              html.a([attribute.href("https://hexdocs.pm/wisp")], [
                hexdocs_icon([attribute.class("size-5")]),
                html.text("HexDocs"),
              ]),
            ]),
            html.li([attribute.class("special-link")], [
              html.a([attribute.href("https://github.com/lpil")], [
                heart_icon([attribute.class("size-5")]),
                html.text("Sponsor"),
              ]),
            ]),
          ]),
        ]),
        user_icon([attribute.class("size-6")]),
      ]),

      html.div([attribute.class("text-center")], [
        html.figure([attribute.class("mb-8 relative w-max mx-auto")], [
          html.img([
            attribute.alt("Wisp Logo"),
            attribute.src("/images/logo.svg"),
            attribute.class("mx-auto"),
          ]),
          html.span([attribute.class("version-label")], [
            html.text("v" <> version),
          ]),
        ]),
        html.p([attribute.class("leading-relaxed max-w-[50ch] mx-auto")], [
          html.text(
            "Build practical, performant, intuitive web applications with Gleam",
          ),
        ]),
      ]),
    ]),
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

fn guide_icon(attrs) {
  svg.svg(
    [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 14 18"),
      ..attrs
    ],
    [
      svg.mask(
        [attribute("fill", "white"), attribute.id("path-1-inside-1_542_330")],
        [
          svg.rect([
            attribute("rx", "1"),
            attribute("height", "16"),
            attribute("width", "14"),
          ]),
        ],
      ),
      svg.rect([
        attribute("mask", "url(#path-1-inside-1_542_330)"),
        attribute("stroke-width", "4"),
        attribute("stroke", "currentColor"),
        attribute("rx", "1"),
        attribute("height", "16"),
        attribute("width", "14"),
      ]),
      svg.mask(
        [attribute("fill", "white"), attribute.id("path-2-inside-2_542_330")],
        [
          svg.rect([
            attribute("rx", "1"),
            attribute("height", "5"),
            attribute("width", "14"),
            attribute("y", "11"),
          ]),
        ],
      ),
      svg.rect([
        attribute("mask", "url(#path-2-inside-2_542_330)"),
        attribute("stroke-width", "4"),
        attribute("stroke", "currentColor"),
        attribute("rx", "1"),
        attribute("height", "5"),
        attribute("width", "14"),
        attribute("y", "11"),
      ]),
      svg.path([
        attribute("fill", "currentColor"),
        attribute(
          "d",
          "M3 13H7V17C7 17.5523 6.55228 18 6 18H4C3.44772 18 3 17.5523 3 17V13Z",
        ),
      ]),
      svg.path([
        attribute("stroke-linecap", "round"),
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute("d", "M4 5H10M4 8H6H8"),
      ]),
    ],
  )
}

fn source_icon(attrs) {
  svg.svg(
    [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 20 14"),
      ..attrs
    ],
    [
      svg.path([
        attribute("stroke-linecap", "round"),
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute(
          "d",
          "M4.61231 1.00025L1.15417 7.00025L4.61231 13.0002M7.99778 13.0002L11.2076 1.00025M14.696 1.00025L18.1542 7.00025L14.696 13.0002",
        ),
      ]),
    ],
  )
}

fn hexdocs_icon(attrs) {
  svg.svg(
    [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 16 19"),
      ..attrs
    ],
    [
      svg.path([
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute(
          "d",
          "M7.48926 1.46582C7.80397 1.27896 8.19603 1.27896 8.51074 1.46582L14.5107 5.02832C14.8142 5.20849 15 5.53577 15 5.88867V13.1113C15 13.4642 14.8142 13.7915 14.5107 13.9717L8.51074 17.5342C8.19603 17.721 7.80397 17.721 7.48926 17.5342L1.48926 13.9717C1.18582 13.7915 1 13.4642 1 13.1113V5.88867L1.00879 5.75781C1.04849 5.45631 1.2237 5.18601 1.48926 5.02832L7.48926 1.46582Z",
        ),
      ]),
      svg.path([
        attribute("stroke-linecap", "round"),
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute("d", "M5 8H11M5 11.5H7H9"),
      ]),
    ],
  )
}

fn heart_icon(attrs) {
  svg.svg(
    [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 18 16"),
      ..attrs
    ],
    [
      svg.path([
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute(
          "d",
          "M10.3984 2.14062C11.9088 0.619762 14.3542 0.619812 15.8643 2.14062C17.3785 3.66575 17.3785 6.14187 15.8643 7.66699L9 14.5801L2.13574 7.66699C0.621774 6.14191 0.621774 3.6657 2.13574 2.14062C3.64603 0.619854 6.09148 0.619892 7.60156 2.14062L8.29004 2.83398L9 3.54883L9.70996 2.83398L10.3984 2.14062Z",
        ),
      ]),
    ],
  )
}

fn user_icon(attrs) {
  svg.svg(
    [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 14 18"),
      ..attrs
    ],
    [
      svg.circle([
        attribute("stroke-width", "2"),
        attribute("stroke", "currentColor"),
        attribute("r", "3.66667"),
        attribute("cy", "4.66667"),
        attribute("cx", "7.00004"),
      ]),
      svg.mask(
        [attribute("fill", "white"), attribute.id("path-2-inside-1_551_248")],
        [
          svg.path([
            attribute(
              "d",
              "M0 12.8889C0 11.7843 0.895431 10.8889 2 10.8889H12C13.1046 10.8889 14 11.7843 14 12.8889V17.1111H0V12.8889Z",
            ),
          ]),
        ],
      ),
      svg.path([
        attribute("mask", "url(#path-2-inside-1_551_248)"),
        attribute("fill", "currentColor"),
        attribute(
          "d",
          "M-2 12.8889C-2 10.6797 -0.209139 8.88889 2 8.88889H12C14.2091 8.88889 16 10.6797 16 12.8889H12H2H-2ZM2 12.8889M14 17.1111H0H14M-2 17.1111V12.8889C-2 10.6797 -0.209139 8.88889 2 8.88889V12.8889V17.1111H-2ZM12 8.88889C14.2091 8.88889 16 10.6797 16 12.8889V17.1111H12V12.8889V8.88889Z",
        ),
      ]),
    ],
  )
}
