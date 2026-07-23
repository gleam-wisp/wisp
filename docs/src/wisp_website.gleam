import gleam/result
import gleam/uri
import lustre
import lustre/attribute.{attribute}
import lustre/effect
import lustre/element
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
  Docs(slug: String)
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
        Ok(["docs"]) -> Docs("getting-started")
        Ok(["docs", slug]) -> Docs(slug)
        _ -> NotFound
      }
    }

  #(route, modem.init(on_url_change))
}

fn on_url_change(uri: uri.Uri) -> Msg {
  case uri.path_segments(uri.path) {
    [] -> OnRouteChange(Home)
    ["docs"] -> OnRouteChange(Docs("getting-started"))
    ["docs", slug] -> OnRouteChange(Docs(slug))
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
    case route {
      Home ->
        element.fragment([
          html.header([attribute.class("site-hero")], [
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
                    html.a([attribute.href("/docs")], [
                      guide_icon([attribute.class("size-5")]),
                      html.text("Guides"),
                    ]),
                  ]),
                  html.li([], [
                    html.a(
                      [attribute.href("https://github.com/gleam-wisp/wisp")],
                      [
                        source_icon([attribute.class("size-5")]),
                        html.text("Source"),
                      ],
                    ),
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
            ]),

            html.div([attribute.class("text-center py-32")], [
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
              html.p(
                [
                  attribute.class(
                    "leading-relaxed max-w-[50ch] mx-auto font-dm-mono",
                  ),
                ],
                [
                  html.text(
                    "Build practical, performant, intuitive web applications with Gleam",
                  ),
                ],
              ),
            ]),
          ]),
        ])
      Docs(slug:) ->
        html.div([attribute.class("docs-layout")], [
          html.aside([attribute.class("docs-sidebar")], [
            html.a([attribute.href("/"), attribute.class("sidebar-logo")], [
              html.img([
                attribute.src("/images/logo.svg"),
                attribute.alt("Wisp"),
                attribute.class("h-10"),
              ]),
            ]),
            html.nav([], [
              html.h5([], [html.text("Getting Started")]),
              html.ul([], [
                html.li([], [
                  html.a([attribute.href("/docs/a")], [
                    html.text("Installation"),
                  ]),
                  html.a([attribute.href("/docs/" <> slug)], [
                    html.text("Your First App"),
                  ]),
                ]),
              ]),
            ]),
          ]),
          html.main([attribute.class("container")], [
            html.nav([attribute.class("site-nav")], [
              html.div([attribute.class("container")], [
                html.form([attribute.class("nav-search")], [
                  html.input([
                    attribute.type_("text"),
                    attribute.placeholder("Search..."),
                  ]),
                ]),
                html.ul([attribute.class("site-links ml-auto")], [
                  html.li([], [
                    html.a([attribute.href("/docs")], [
                      guide_icon([attribute.class("size-5")]),
                      html.text("Guides"),
                    ]),
                  ]),
                  html.li([], [
                    html.a(
                      [attribute.href("https://github.com/gleam-wisp/wisp")],
                      [
                        source_icon([attribute.class("size-5")]),
                        html.text("Source"),
                      ],
                    ),
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
            ]),
            html.main([], [
              html.header([attribute.class("docs-header")], [
                html.h4([], [html.text("Getting Started")]),
                html.h1([], [html.text("Your First App")]),
              ]),

              html.article([attribute.class("prose")], article_content()),
            ]),
          ]),
        ])
      NotFound -> element.fragment([])
    },
    html.footer([attribute.class("site-footer")], [
      html.div(
        [
          attribute.class(
            "container flex flex-wrap justify-between gap-3 text-sm",
          ),
        ],
        [
          html.p([], [
            html.text("© Wisp Contributors 2026, All Rights Reserved"),
          ]),
          html.p([], [
            html.a(
              [
                attribute.class(
                  "underline decoration-brand-prime transition-opacity hover:opacity-75",
                ),
                attribute.href(
                  "https://github.com/gleam-lang/gleam/blob/main/CODE_OF_CONDUCT.md",
                ),
              ],
              [html.text("Code of Conduct")],
            ),
          ]),
        ],
      ),
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

fn article_content() {
  [
    html.p([], [
      html.text(
        "This is a fun silly post about something that’s bought me joy, but I want to practice blogging and have had this thought on my mind: I've been really enjoying making small things lately. Little web toys, simple Discord bots, super basic shell scripts, and bits and bobs around the house. I find this to be so enjoyable, and so freeing. It’s been really empowering to use the more basic building blocks to create things.",
      ),
    ]),
    html.pre([], [
      html.header([], [
        html.text("shell"),
        html.button([], [html.text("Copy")]),
      ]),
      html.code([], [html.text("$ gleam add wisp")]),
    ]),
    html.p([], [
      html.text("We need to do sometihng relating to "),
      html.code([], [html.text("inline code")]),
    ]),
    html.pre([], [
      html.header([], [
        html.text("main.gleam"),
        html.button([], [html.text("Copy")]),
      ]),
      html.code([], [
        html.span([attribute.class("hl-comment")], [
          html.text(
            "// Recursively create the dist directory structure we want",
          ),
        ]),
        html.text("\n"),
        html.span([attribute.class("hl-module")], [html.text("simplifile")]),
        html.text("."),
        html.span([attribute.class("hl-function")], [
          html.text("create_directory_all"),
        ]),
        html.text("("),
        html.span([attribute.class("hl-string")], [
          html.text("\"./dist/pixels\""),
        ]),
        html.text(")"),
        html.text("\n"),
        html.text("\n"),
        html.span([attribute.class("hl-comment")], [
          html.text("// Read a directory"),
        ]),
        html.text("\n"),
        html.span([attribute.class("hl-keyword")], [html.text("let")]),
        html.span([attribute.class("hl-keyword")], [html.text(" assert ")]),
        html.span([attribute.class("hl-variant")], [html.text("Ok")]),
        html.text("(entries) = "),
        html.span([attribute.class("hl-module")], [html.text("simplifile")]),
        html.text("."),
        html.span([attribute.class("hl-function")], [
          html.text("read_directory"),
        ]),
        html.text("("),
        html.span([attribute.class("hl-string")], [html.text("\"./pixelart\"")]),
        html.text(")"),
        html.text("\n"),
        html.text("\n"),
        html.span([attribute.class("hl-comment")], [
          html.text(
            "// Loop through it and copy all the entries over to a build directory",
          ),
        ]),
        html.text("\n"),
        html.span([attribute.class("hl-module")], [html.text("list")]),
        html.text("."),
        html.span([attribute.class("hl-function")], [html.text("each")]),
        html.text("(entries,"),
        html.span([attribute.class("hl-keyword")], [html.text("fn")]),
        html.text("(entry) {"),
        html.text("\n"),
        html.span([attribute.class("hl-module")], [html.text("  simplifile")]),
        html.text("."),
        html.span([attribute.class("hl-function")], [html.text("copy")]),
        html.text("("),
        html.span([attribute.class("hl-string")], [html.text("\"./pixelart/\"")]),
        html.span([attribute.class("hl-operator")], [html.text(" <> ")]),
        html.text("entry, "),
        html.span([attribute.class("hl-string")], [
          html.text("\"./dist/pixels/\""),
        ]),
        html.text(")\n})"),
      ]),
    ]),
    html.p([], [
      html.text(
        "While I’ve needed to focus more on productive work, I sort of lost touch with that part of myself a few years ago, and I’ve been very much in a state of rolling with the punches, I suppose. For example, if I needed a piece of software, I’d try to find something off the shelf before I tried to build my own. I don’t think the DIY attitude is ‘normal’ or always a good idea. Of course, you can end up stuck in a loop of building existing things, having to relearn a bunch of lessons others have already learned.",
      ),
    ]),
    html.p([], [
      html.text(
        "It’s important to me, for my own joy and growth, to rip things apart and build things from scratch, to understand the underlying structure of the world. Rediscovering that drive has been so fun. I think fun is really important. I can tend to get very bogged-down in thinking about the pain of the world, and it can be quite paralysing. I don’t think getting immobilised by that pain is productive at all.",
      ),
    ]),
    html.p([], [
      html.text(
        "Here’s a list of the small-scale stuff I’ve been doing over the past few months, I really hope you feel a bit inspired to bodge together some stuff of your own.",
      ),
    ]),
    html.h2([attribute.id("Pablo-Pixarto")], [
      html.text("Pablo Pixarto"),
    ]),
    html.p([], [
      html.text(
        "For a bit over a year now, I’ve been doing a piece of pixel art every day, following the @pixeldailies.bsky.app prompts, which I used to get delivered from their Discord server. Unfortunately, one of the moderators of that server got phished a few months ago, and their account was used to phish a number of other moderators (and others) in the server. Numerous regular posters (including me) were also banned.",
      ),
    ]),
    html.p([], [
      html.text(
        "Unfortunately, the server was totally vandalised and used to spread a virus, in the form of the old classic ‘download our new game!’ trick. Despite a moderator or two since regaining access to their accounts, the vast majority of the server history is gone and it is still in an unusable state. This was such a blow to me, because that pixel art community has made the daily prompts so much more engaging to follow, and has given it a real sense of purpose.",
      ),
    ]),
    html.p([], [
      html.text(
        "After waiting to see if the server could be recovered, I decided to just",
      ),
      html.a([attribute.href("https://isaac.zone/pixel-paradise")], [
        html.text("create a new server"),
      ]),
      html.text(
        ", which has been really quite successful! I’m very grateful to have numerous regular, active artists in the server, and no matter what level you’re at, I’d love to have you in there too!",
      ),
    ]),
    html.p([], [
      html.text(
        "I decided it would be fun to make a tiny Discord bot (which, arguably, could currently just be a webhook) to retrieve the latest prompt from the Bluesky account, then post and publish it to the theme channel in the server. This works super well, and was really easy to make! I used",
      ),
      html.a([attribute.href("https://gleam.run")], [html.text("Gleam")]),
      html.text(", and the fairly young"),
      html.a([attribute.href("https://hexdocs.pm/grom/")], [
        html.text("grom"),
      ]),
      html.text(
        "library, which was quite pleasant. There’s some other ideas I have for the bot, but for now it’s already been quite valuable. It’s a great example of a project that I could easily over-engineer, plugging it into a database, doing some funky ATProto stuff, doing better filtering to ensure the right posts are put through, the list goes on!",
      ),
    ]),
    html.p([], [
      html.text(
        "While it’s fun to think about all those possibilities, just checking for a couple of key words in the post and caching the already-posted prompts in a JSON file was enough to get off the ground. The only meaningful problem I ran into was that the account sometimes posts a theme and then retracts it within 5-10 seconds. This occasionally lead to more than one post going in the themes channel of the server, but was solved by just ensuring the themes I post are more than 60 seconds old.",
      ),
    ]),
    html.h2([attribute.id("I-forgot…")], [html.text("I forgot…")]),
    html.p([], [
      html.text(
        "I’ve had Zeppelin, the Discord bot, a few servers I frequent for a few years now, and one of the most surprisingly useful features is the !remind command. Setting short term reminders that tag me on a platform I have on both my desktop computer & phone is super handy to me. It also means I can set shared reminders for things I need to check in with friends for.",
      ),
    ]),
    html.p([], [
      html.text(
        "The only gap I found was that all reminders are public to some degree, because you have to set them in a server channel. I really wanted to have a similar interface but for personal reminders. Things like ‘take your washing out’ because apparently the machine sound isn’t enough to remind me of this.",
      ),
    ]),
    html.p([], [
      html.text("I decided to try out the"),
      html.a([attribute.href("https://serenity-rs.github.io/")], [
        html.text("Serenity"),
      ]),
      html.text(
        "Discord library and Rust for this project, which was super super fun. I find Rust to be too heavy-handed for a lot of my projects and don’t often reach for it, but I am such a fan of much of Rust and it’s ecosystem. The performance characteristics, such as low memory usage and relatively small binaries, are a massive plus to me also.",
      ),
    ]),
    html.p([], [
      html.text(
        "I’m a container fan. If I can, I will run just about anything in a container. I use Docker (and Podman) for both development and production deployments of databases, APIs, webservers, bots, you name it! I would normally default to just slapping together a Dockerfile and calling it a day, but in the spirit of bodging, I decided to write a shell script to deploy it to my home server, and run it as a systemd service.",
      ),
    ]),
    html.p([], [
      html.text(
        "This was so much fun. My sort of naive security assumption was that I should probably have a user account for deployment and a second account for actually running the service. I can only hope this is smart enough for me to get away with it, but either way my local network is locked down pretty hard to incoming requests. I also fully locked the runner account to only have access to the necessary systemd commands to restart the service, and the deploy account to only have access to the specific location of the binary.",
      ),
    ]),
    html.p([], [
      html.text("I was inspired to try this out after watching a"),
      html.a([attribute.href("https://www.youtube.com/watch?v=7VSVfQcaxFY")], [
        html.text("video about Lichess"),
      ]),
      html.text(
        ", which deploys it’s central service in a very similar way. It feels so cool to use the basic tech like this. Build the binary, rsync to the server, run with systemd. Nothing complex, no Python, no Ansible, just good old shell scripts and unix command line tools. I highly recommend doing something like this, it feels really cool.",
      ),
    ]),
    html.h2([attribute.id("Hy-there")], [html.text("Hy there")]),
    html.p([], [
      html.text(
        "To my surprise, the game Hytale actually released recently, thanks to Simon from Hypixel buying it back off Riot Games. I’m super interested to see what might come of Hytale, I think it shows a lot of promise as a platform for making games on, sort of similar to Minecraft or Roblox (or so I’m told, I’ve never played it or used it, but go Lua!)",
      ),
    ]),
    html.p([], [
      html.text(
        "A friend of mine started a Hytale server and wanted a way to show the playercount on the server website, which Hytale currently doesn’t (really) support. My janky solution was to make a CloudFlare Workers/D1 powered HTTP API to act as a leap pad between the actual Hytale server and the website for the server. This meant getting my hands dirty by writing a Java plugin too, which was both exciting and had me let out a bit of a groan.",
      ),
    ]),
    html.p([], [
      html.text(
        "Honestly though, the Java plugin was super fun to make. It is super simple, it just gets the player count and sends a request to the API every 60 seconds, authorised with a key. The worker then stores the host IP of the request from the server and the playercount. Then on the other end, when you GET the endpoint and public address, it resolves the server IP and gives you the count. It’s janky, I know, but it was super fun to make.",
      ),
    ]),
    html.p([], [
      html.text("I used Gleam for the worker which was fun, using the"),
      html.a(
        [
          attribute.href("https://hexdocs.pm/plinth_cloudflare/index.html"),
        ],
        [html.text("plinth_cloudflare")],
      ),
      html.text(
        "package. It was alright, but I think in the future I might prefer to write my own FFI. The Hytale server API feels a heck of a lot nicer than what I remember of the Minecraft (/ Bukkit / Spigot / Paper / NMS / boy there’s too many of these) plugin space. Really cool stuff, I hope people make cool things on Hytale. I’d love to play around with it a bit more too. If you’d like to check it out, feel free to send me a message and I can authorise your Discord account to create servers on",
      ),
      html.a([attribute.href("https://hytapi.com")], [
        html.text("the site"),
      ]),
      html.text("."),
    ]),
    html.h2([attribute.id("Do-count-on-it")], [
      html.text("Do count on it"),
    ]),
    html.p([], [
      html.text(
        "My partner is a primary school teacher, and their class is made up of 5-year-old students this year. For that cohort, they need to spend a lot of time on basic literacy and numeracy skills, like subitizing, counting, and building up quick recognition of numbers in forms like dominoes, tally marks, etc. For teaching this, they’ve made a stack of slide presentations, which are great, but not easy to mix and match.",
      ),
    ]),
    html.p([], [
      html.text(
        "This is such a great usecase for a little website. Take a bunch of images and show them in random order? I can totally do that! I wrote a simple",
      ),
      html.a([attribute.href("https://hexdocs.pm/lustre")], [
        html.text("Lustre"),
      ]),
      html.text(
        "application that does just this – and it has been working out well for my partner and the rest of their team. I also tried to add support for a presentation clicker, but I haven’t quite locked down what events to listen for there, because so many of the clickers work in different ways. It’s really exciting to make something like this which is technologically straight-forward and has real-world impact. One of the best types of projects for me, despite being a simple problem with an obvious solution.",
      ),
    ]),
    html.h2([attribute.id("Listen-here…")], [html.text("Listen here…")]),
    html.p([], [
      html.text(
        "My primary headphones, a near-10-year-old pair of M50x’s, have suffered through a few thousand drops and other forms of battering, and unfortunately finally took a hit they couldn’t just jump back up from, as I snapped the little piece of plastic that prevents the ear from folding out beyond a certain point. With this bit gone, they wouldn’t close around my ears and were very uncomfortable.",
      ),
    ]),
    html.p([], [
      html.text(
        "After a few attempts at tying it together with tape or elastic, I disassembled them and tried to resolve the underlying issue. I’m embarrassed to admit that I spent twenty minutes totally tunnel-visioned on little screws and didn’t realise I was taking apart the wrong side. A long sigh and short while later, I was actually down to the right part of the right side, and managed to get it back to an acceptable state with an overly generous drizzle of Superglue (which also coated all 10 of my fingers, somehow).",
      ),
    ]),
    html.p([], [
      html.text(
        "This is the second fix I’ve done to these headphones – other than cable replacements, which I have to do far too often. I despise the non-standard input – the other fix being a new cover for the headband part. After so many years, the majority of the leather (faux leather, perhaps?) had peeled off and gotten stuck into my floor, so it was time to replace it. After numerous attempts at cutting and sewing some material, I finally got a piece that fit nicely and stayed in the right spot.",
      ),
    ]),
    html.p([], [
      html.text(
        "Fixing these two things, as well as making a new mount to store them on so I’m less likely to drop them, was super satisfying. The thought of getting a new pair did cross my mind, but it felt wrong to give up on something that was still in a working, repairable state. Beyond the money savings, I feel like I’ve gained a new appreciation for the complexity of making a nice pair of headphones and how long they’ve survived my torment. Overall, very satisfied.",
      ),
    ]),
    html.hr([]),
    html.p([], [
      html.text(
        "Thanks for reading, if you’ve made it this far, I appreciate you. If you just skipped to the end, I still appreciate you, but maybe a little less ;) Get some water and stretch!",
      ),
    ]),
  ]
}
