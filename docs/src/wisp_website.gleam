import contour
import frontmatter
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import gleam_community/ansi
import jot
import lustre/attribute.{attribute as attr, class, href} as attr
import lustre/element
import lustre/element/html.{text}
import simplifile
import tom

type Meta(a) {
  Meta(
    title: String,
    description: String,
    cover: Option(String),
    extra: List(element.Element(a)),
  )
}

const version = "2.2.2"

const guide_sections = [
  GuideSection("Getting Started", "getting-started", []),
  GuideSection("Examples", "examples", []),
]

pub fn main() {
  let start_time = timestamp.system_time()

  io.println(ansi.green("[Wisp]") <> " Building static docs site...")
  // Create the dist directory. We void the error here because it's fine if
  // the directory already exists.
  let _ = simplifile.create_directory("./dist")

  // Clear the dist directory so it's ready for our newly built files.
  let assert Ok(_) = simplifile.clear_directory("./dist")

  io.println(ansi.green("✓") <> " Cleared and created dist directory")

  io.println(ansi.green("✓") <> " Building output CSS file")
  let assert Ok(static_asset_files) = simplifile.read_directory("./assets")

  let static_assets =
    list.map(static_asset_files, fn(asset) {
      let assert Ok(is_dir) = simplifile.is_directory("./assets/" <> asset)
      let assert Ok(_) =
        simplifile.copy(src: "./assets/" <> asset, dest: "./dist/" <> asset)

      #(asset, is_dir)
    })

  io.print(ansi.green("-") <> " Generating docs ")

  let guides =
    list.map(guide_sections, fn(category) {
      let assert Ok(files) =
        simplifile.read_directory("./content/" <> category.slug)

      // Create the output directory
      let assert Ok(_) =
        simplifile.create_directory_all("./dist/docs/" <> category.slug)

      let guides =
        list.map(files, fn(file_name) {
          let assert Ok(content) =
            simplifile.read("./content/" <> category.slug <> "/" <> file_name)
          let assert frontmatter.Extracted(Some(frontmatter), content) =
            frontmatter.extract(content)

          let assert Ok(frontmatter) = tom.parse(frontmatter)
          let assert Ok(title) = tom.get_string(frontmatter, ["title"])
          let assert Ok(description) =
            tom.get_string(frontmatter, ["description"])
          let assert Ok(published_at) =
            tom.get_date(frontmatter, ["published_at"])
          let assert Ok(updated_at) = tom.get_date(frontmatter, ["updated_at"])
          let assert Ok(order) = tom.get_int(frontmatter, ["order"])

          let slug = string.replace(file_name, ".djot", "")

          let document = jot.parse(content)
          let document =
            jot.Document(
              ..document,
              content: list.map(document.content, fn(item) {
                case item {
                  jot.Codeblock(language: Some("gleam"), content:, ..) ->
                    jot.RawBlock(
                      "<pre><code>"
                      <> contour.to_html(content)
                      <> "</code></pre>",
                    )
                  _ -> item
                }
              }),
            )

          Guide(
            slug:,
            title:,
            description:,
            published_at:,
            updated_at:,
            order:,
            content: document,
          )
        })
        |> list.sort(fn(a, b) { int.compare(a.order, b.order) })

      GuideSection(..category, guides:)
    })

  let guide_pages =
    list.fold(guides, [], fn(acc, section) {
      list.fold(section.guides, acc, fn(acc, guide) {
        [
          #(
            "docs/" <> section.slug <> "/" <> guide.slug <> ".html",
            doc_page(guides, section.title, guide.title, guide.content),
            Meta(
              title: guide.title <> " - Wisp Guides",
              description: guide.description,
              cover: None,
              extra: [
                html.link([
                  attr.href("/pagefind/pagefind-component-ui.css"),
                  attr.rel("stylesheet"),
                ]),
                html.script(
                  [
                    attr.src("/pagefind/pagefind-component-ui.js"),
                    attr.type_("module"),
                  ],
                  "",
                ),
              ],
            ),
          ),
          ..acc
        ]
      })
    })

  io.print(ansi.green("-") <> " Building static pages ")

  let pages =
    [
      #(
        "index.html",
        home(),
        Meta(
          title: "Wisp: Practical, performant, intuitive web applications with Gleam",
          description: "The go-to web server framework for Gleam, from beginners to scale.",
          cover: None,
          extra: [],
        ),
      ),
      #(
        "404.html",
        not_found(),
        Meta(
          title: "Page Not Found - Wisp",
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
          cover: None,
          extra: [],
        ),
      ),
      #(
        "docs/index.html",
        docs_index(guides),
        Meta(
          title: "Wisp Guides and Documentation",
          cover: None,
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
          extra: [],
        ),
      ),
      ..guide_pages
    ]
    |> list.map(fn(page) {
      let #(path, view, meta) = page

      let html =
        layout(view, meta)
        |> element.to_document_string

      let assert Ok(_) = simplifile.write(to: "./dist/" <> path, contents: html)
      io.print(ansi.bold(ansi.yellow("•")))

      path
    })

  // Print a blank line to leave a gap after pages
  io.println("")

  io.println(ansi.green("✓") <> ansi.bold(" Success! Output:"))
  list.each(static_assets, fn(static) {
    case static {
      #(folder_name, True) ->
        io.println(
          " - " <> ansi.grey("dist/") <> ansi.cyan(folder_name <> "/*"),
        )
      #(file_name, False) ->
        io.println(" - " <> ansi.grey("dist/") <> ansi.cyan(file_name))
    }
  })
  list.each(pages, fn(page) {
    io.println(" - " <> ansi.grey("dist/") <> ansi.cyan(page))
  })

  let end_time = timestamp.system_time()
  let difference =
    duration.to_milliseconds(timestamp.difference(start_time, end_time))

  io.println(
    "\n"
    <> ansi.green("🛈")
    <> ansi.bold(" Finished in " <> int.to_string(difference) <> "ms"),
  )
}

fn home() {
  let feature_grid = [
    #(
      "Perfectly productive",
      "Wisp is simple, type safe, and entirely free from confusing magic. Make development as stress-free as possible whether you're starting a new prototype or maintaining a large system.",
    ),
    #(
      "Flipping fast",
      "Thanks to the Mist HTTP server and the mighty multithreaded BEAM runtime Wisp applications are fast, even at the 99th percentile during a big burst of traffic.",
    ),
    #(
      "Totally testable",
      "If your application matters, you're going to want to test it. A Wisp web application is as easy to test as any regular Gleam function, and an assortment of useful test helpers are provided to keep your tests concise.",
    ),
    #(
      "Really reliable",
      "Scrambling to fix problems in production is stressful, so Wisp uses Gleam's type safety and the BEAM's fault tolerance help prevent those panicked late night phone calls from your boss.",
    ),
  ]

  let spotlight_features = [
    #(
      "Easy middleware",
      "Use Wisp's built-in middleware and write your own, with ease.",
    ),
    #(
      "Simple, fast routing",
      "Good old-fashioned pattern matching to direct your requests.",
    ),
    #(
      "Request parsers",
      "Easily parse JSON, urlencoded data, or multipart form bodies with built-in parsers.",
    ),
    #(
      "Tamper-proof cookies",
      "Signed cookies, suitable for authentication, work right out of the box.",
    ),
    #(
      "Simple static assets",
      "Serve CSS, JavaScript, and any other static assets you need with included middleware.",
    ),
    #(
      "Logs a-plenty",
      "Use the BEAM logger to log requests with middleware and ad-hoc logging inside requests",
    ),
    #(
      "Backed by Gleam",
      "Regular Gleam programming with no special magic. Use any Gleam package you want, with ease.",
    ),
    #(
      "Well documented",
      "Follow the Wisp guides and examples whether you're just starting out or maintaining a big project.",
    ),
    #(
      "Recommended structure",
      "We supply a recommended project structure so you can focus on the issues your app is trying to solve.",
    ),
  ]

  let header_code =
    contour.to_html(
      "use <- wisp.log_request(req)
use json <- wisp.require_json(req)  

let result = {
  use params <- try(people.parse_params(json)) 
  use person <- try(people.save(params, ctx.db))
  Ok(people.to_json(person))
}

case result {
  Ok(body) -> wisp.json_response(body, 201)
  Error(_) -> wisp.bad_request()
}",
    )

  let code_example =
    contour.to_html(
      "import my_app/people
import my_app/web.{Context}
import gleam/result.{try}
import wisp.{Request, Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req) // Built in middleware

  let result = {
    use params <- try(people.parse_params(json))
    use person <- try(people.save(params, ctx.db))
    Ok(people.to_json(person))
  }

  case result {
    Ok(body) -> wisp.json_response(body, 201) // Encode your JSON response
    Error(_) -> wisp.bad_request() // Helpers for common error responses
  }
}",
    )

  element.fragment([
    html.header([class("site-hero")], [
      site_nav(False),

      html.section([class("text-center py-32")], [
        html.figure([class("mb-8 relative w-max mx-auto")], [
          html.img([
            attr.alt("Wisp Logo"),
            attr.src("/images/logo.svg"),
            class("mx-auto"),
          ]),
          html.span([class("version-label")], [
            text("v" <> version),
          ]),
        ]),
        html.p(
          [
            class(
              "leading-relaxed text-prose-strong max-w-[50ch] mx-auto font-mono",
            ),
          ],
          [
            text(
              "Build practical, performant, intuitive web applications with Gleam",
            ),
          ],
        ),
      ]),
    ]),

    html.section([class("container")], [
      html.img([
        attr.src("/images/handler-graphic.svg"),
        attr.alt(
          "Graphic showing requests, a basic Wisp function, and some users making requests, all connected with squigglies.",
        ),
        class("max-lg:hidden"),
      ]),
      html.div([class("lg:hidden")], [
        html.ul(
          [
            class(
              "flex items-center justify-center flex-wrap gap-3 mb-4 text-sm",
            ),
          ],
          [
            html.li(
              [
                class(
                  "bg-white rounded-md border border-brand-quitelight font-mono py-2 px-3",
                ),
              ],
              [
                html.span([class("text-brand-prime")], [text("GET")]),
                text(" /dashboard"),
              ],
            ),
            html.li(
              [
                class(
                  "bg-white rounded-md border border-brand-quitelight font-mono py-2 px-3",
                ),
              ],
              [
                html.span([class("text-amber-700")], [text("POST")]),
                text(" /api/people"),
              ],
            ),
            html.li(
              [
                class(
                  "bg-white rounded-md border border-brand-quitelight font-mono py-2 px-3",
                ),
              ],
              [
                html.span([class("text-red-700")], [text("DELETE")]),
                text(" /api/people/lucy"),
              ],
            ),
            html.li(
              [
                class(
                  "bg-white rounded-md border border-brand-quitelight font-mono py-2 px-3",
                ),
              ],
              [
                html.span([class("text-brand-prime")], [text("GET")]),
                text(" /static/main.css"),
              ],
            ),
          ],
        ),
        html.div([class("prose")], [
          html.pre([], [element.unsafe_raw_html("", "code", [], header_code)]),
        ]),
      ]),
    ]),

    html.section([class("py-16 lg:py-24 xl:py-32")], [
      html.h3([class("font-bold text-3xl text-center mb-8 font-mono")], [
        text("Why use Wisp?"),
      ]),

      html.div(
        [
          class("container"),
        ],
        [
          html.ul(
            [class("feature-grid")],
            list.map(feature_grid, fn(feature) {
              let #(title, body) = feature
              html.li([], [
                html.h4([], [text(title)]),
                html.p([], [
                  text(body),
                ]),
              ])
            }),
          ),
        ],
      ),
    ]),

    html.section([class("bg-white py-16 lg:py-24 xl:py-32")], [
      html.h3([class("font-bold text-3xl text-center mb-8 font-mono")], [
        text("What does Wisp give me?"),
      ]),

      html.div([class("container")], [
        html.ul(
          [class("highlights-list")],
          list.map(spotlight_features, fn(spotlight) {
            let #(title, body) = spotlight
            html.li([], [
              html.h4([], [text(title)]),
              html.p([], [text(body)]),
            ])
          }),
        ),
      ]),
    ]),

    html.section([class("py-16 lg:py-24 xl:py-32")], [
      html.h3([class("font-bold text-3xl text-center mb-8 font-mono")], [
        text("Okay, I'm in. How does it look?"),
      ]),

      html.div(
        [
          class("container"),
        ],
        [
          html.p([class("text-center max-w-3xl mx-auto mb-3")], [
            text(
              "Here's a JSON API request handler that saves an item in a database:",
            ),
          ]),
          html.pre([class("code-example")], [
            element.unsafe_raw_html("", "code", [], code_example),
          ]),
        ],
      ),
    ]),

    html.section([class("container")], [
      html.div([class("guide-cta")], [
        html.p([], [text("Ready to learn more?")]),
        html.a([attr.href("/docs")], [text("Read the Guides")]),
      ]),
    ]),

    site_footer(2026, [class("lg:col-span-4")]),
  ])
}

fn docs_index(sections: List(GuideSection)) {
  element.fragment([
    html.header([class("site-hero")], [
      site_nav(is_content: False),
      html.div([class("container")], [
        html.header([class("docs-header")], [
          html.h1([], [text("Guides")]),
          html.p([], [
            text(
              "Whether you're creating your first Gleam project or looking for best practices, check out the Wisp guides.",
            ),
          ]),
        ]),
      ]),
    ]),

    html.div(
      [class("container grid lg:grid-cols-4 gap-6 lg:gap-y-12")],
      list.map(sections, fn(section) {
        element.fragment([
          html.aside([], [
            html.h2(
              [
                class("font-bold text-xl text-color-text-strong"),
              ],
              [text(section.title)],
            ),
          ]),
          html.main([class("lg:col-span-3")], [
            html.ul(
              [
                class("docs-links grid gap-3 lg:grid-cols-2 guides-overview"),
              ],
              list.map(section.guides, fn(guide) {
                html.li([], [
                  html.a([href("/docs/" <> section.slug <> "/" <> guide.slug)], [
                    html.h3([], [text(guide.title)]),
                    html.p([], [
                      text(guide.description),
                    ]),
                  ]),
                ])
              }),
            ),
          ]),
          html.div(
            [
              class("h-px bg-brand-quitelight lg:col-span-4 last:hidden"),
            ],
            [],
          ),
        ])
      }),
    ),
    site_footer(2026, []),
  ])
}

fn doc_page(
  guides: List(GuideSection),
  section_name: String,
  title: String,
  content: jot.Document,
) {
  html.div([class("docs-layout")], [
    // CSS only sidebar toggling for mobile
    html.input([
      class("sidebar-toggle-input"),
      attr.type_("checkbox"),
      attr.id("sidebar-toggle"),
    ]),

    html.aside([class("docs-sidebar")], [
      html.header([class("sidebar-header")], [
        html.a([href("/"), class("sidebar-logo")], [
          html.img([
            attr.src("/images/logo.svg"),
            attr.alt("Wisp"),
            class("h-10"),
          ]),
        ]),
        html.label(
          [
            attr.role("button"),
            attr.class("sidebar-close-button"),
            attr.for("sidebar-toggle"),
            attr.aria_label("Close sidebar"),
          ],
          [text("×")],
        ),
      ]),
      ..list.map(guides, fn(section) {
        html.nav([], [
          html.h5([], [text(section.title)]),
          html.ul(
            [],
            list.map(section.guides, fn(guide) {
              html.li([], [
                html.a([href("/docs/" <> section.slug <> "/" <> guide.slug)], [
                  text(guide.title),
                ]),
              ])
            }),
          ),
        ])
      })
    ]),

    html.main([class("container")], [
      site_nav(is_content: True),

      html.header([class("docs-header")], [
        html.h4([], [text(section_name)]),
        html.h1([], [text(title)]),
      ]),

      html.div([class("grid gap-4 lg:gap-8 lg:grid-cols-4")], [
        html.main([class("lg:col-span-3")], [
          element.unsafe_raw_html(
            "",
            "article",
            [class("prose")],
            jot.document_to_html(content),
          ),
        ]),

        html.aside([], [
          html.nav([class("table-of-contents")], [
            html.ul([], [
              html.li([], [text("On this page")]),
              ..list.map(page_contents_from_markup(content), fn(title) {
                html.li([], [
                  html.a([href("#" <> title.1)], [
                    text(title.0),
                  ]),
                ])
              })
            ]),
          ]),
        ]),
      ]),

      site_footer(2026, [class("lg:col-span-4")]),
    ]),
  ])
}

fn not_found() {
  element.fragment([
    html.header([class("site-hero")], [
      site_nav(is_content: False),

      html.div([class("text-center py-32")], [
        html.figure([class("mb-8 relative w-max mx-auto")], [
          html.img([
            attr.alt("Wisp Logo"),
            attr.src("/images/logo.svg"),
            class("mx-auto"),
          ]),
          html.span([class("version-label")], [
            text("v" <> version),
          ]),
        ]),
        html.h1([class("font-bold text-3xl mb-3")], [
          text("Page not found"),
        ]),
        html.p(
          [
            class("leading-relaxed text-prose-strong max-w-[50ch] mx-auto"),
          ],
          [
            text(
              "Sorry! It looks like the page you were looking for could not be found. Check the address bar to see if there is a clear mistake, or ",
            ),
            html.a(
              [
                href("/"),
                class("underline decoration-brand-prime font-medium"),
              ],
              [
                text("return home"),
              ],
            ),
          ],
        ),
      ]),
    ]),
    site_footer(2026, []),
  ])
}

fn layout(body: element.Element(a), meta: Meta(a)) -> element.Element(a) {
  html.html([attr.lang("en")], [
    html.head([], [
      html.meta([attr("charset", "UTF-8")]),
      html.meta([
        attr("content", "width=device-width, initial-scale=1.0"),
        attr.name("viewport"),
      ]),
      html.meta([
        attr("content", "ie=edge"),
        attr("http-equiv", "X-UA-Compatible"),
      ]),
      html.title([], meta.title),
      html.link([
        attr.href("/images/icon.svg"),
        attr.rel("icon"),
        attr.type_("image/svg"),
      ]),
      html.link([attr.href("/images/icon.svg"), attr.rel("apple-touch-icon")]),
      html.meta([
        attr("content", meta.title),
        attr("property", "og:title"),
      ]),
      html.meta([
        attr("content", meta.title),
        attr("property", "twitter:title"),
      ]),
      html.meta([
        attr("content", meta.description),
        attr.name("description"),
      ]),
      html.meta([
        attr("content", meta.description),
        attr.name("og:description"),
      ]),
      html.meta([
        attr("content", meta.description),
        attr.name("twitter:description"),
      ]),
      html.meta([
        attr("content", "website"),
        attr("property", "og:type"),
      ]),
      html.meta([
        attr("content", "https://gleam-wisp.github.io/wisp/"),
        attr("property", "og:url"),
      ]),
      html.meta([
        attr("content", option.unwrap(meta.cover, "/images/cover.png")),
        attr("property", "og:image"),
      ]),
      html.meta([
        attr("content", option.unwrap(meta.cover, "/images/cover.png")),
        attr("property", "twitter:image"),
      ]),
      html.meta([
        attr("content", "summary_large_image"),
        attr("property", "twitter:card"),
      ]),
      html.link([
        attr.rel("stylesheet"),
        attr.href("/styles.css"),
      ]),
      ..meta.extra
    ]),
    html.body([], [body]),
  ])
}

pub type GuideSection {
  GuideSection(title: String, slug: String, guides: List(Guide))
}

pub type Guide {
  Guide(
    slug: String,
    title: String,
    description: String,
    published_at: calendar.Date,
    updated_at: calendar.Date,
    order: Int,
    content: jot.Document,
  )
}

fn site_nav(is_content is_content: Bool) {
  html.nav([class("site-nav")], [
    html.div([class("container")], [
      case is_content {
        True ->
          html.div([class("nav-search")], [
            element.element("pagefind-modal-trigger", [], []),
            element.element("pagefind-modal", [], []),
          ])

        False ->
          html.a([href("/"), class("site-logo")], [
            html.img([
              attr.src("/images/logo.svg"),
              attr.alt("Wisp logo"),
              class("h-12"),
            ]),
          ])
      },
      html.ul([class("site-links")], [
        html.li([], [
          html.a([href("/docs")], [
            html.img([
              attr.src("/images/guides-icon.svg"),
              attr.class("size-5"),
              attr.alt("Guides Icon"),
            ]),
            text("Guides"),
          ]),
        ]),
        html.li([], [
          html.a([href("https://github.com/gleam-wisp/wisp")], [
            html.img([
              attr.src("/images/source-icon.svg"),
              attr.class("size-5"),
              attr.alt("Source Icon"),
            ]),
            text("Source"),
          ]),
        ]),
        html.li([], [
          html.a([href("https://wisp.hexdocs.pm/")], [
            html.img([
              attr.src("/images/hexdocs-icon.svg"),
              attr.class("size-5"),
              attr.alt("HexDocs (unofficial) Icon"),
            ]),
            text("HexDocs"),
          ]),
        ]),
        html.li([class("special-link")], [
          html.a([href("https://github.com/lpil")], [
            html.img([
              attr.src("/images/heart-icon.svg"),
              attr.class("size-5"),
              attr.alt("Heart Icon"),
            ]),
            text("Sponsor"),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn site_footer(
  year: Int,
  attrs: List(attr.Attribute(a)),
) -> element.Element(a) {
  html.footer([class("site-footer"), ..attrs], [
    html.div(
      [
        class("container flex flex-wrap justify-between gap-3 py-8"),
      ],
      [
        html.p([class("font-medium text-sm")], [
          text(
            "© Wisp Contributors "
            <> int.to_string(year)
            <> ". All Rights Reserved.",
          ),
        ]),
        html.nav([], [
          html.a(
            [
              class(
                "underline decoration-brand-prime transition-opacity hover:opacity-75",
              ),
              href(
                "https://github.com/gleam-lang/gleam/blob/main/CODE_OF_CONDUCT.md",
              ),
            ],
            [text("Code of Conduct")],
          ),
        ]),
      ],
    ),
  ])
}

fn page_contents_from_markup(
  document: jot.Document,
) -> List(#(String, String)) {
  list.fold(document.content, [], fn(acc, container) {
    case container {
      jot.Heading(level:, content: [jot.Text(title)], attributes:)
        if level < 4
      ->
        case dict.get(attributes, "id") {
          Ok(href) -> [#(title, href), ..acc]
          _ -> acc
        }
      _ -> acc
    }
  })
  |> list.reverse()
}
