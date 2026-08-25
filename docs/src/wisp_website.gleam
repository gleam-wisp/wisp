import contour
import frontmatter
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam_community/ansi
import jot
import lustre/attribute.{attribute as attr, class, href} as attr
import lustre/element
import lustre/element/html
import lustre/element/svg
import simplifile
import tom
import wisp_website/demo

type Meta {
  Meta(title: String, description: String)
}

const version = "5.4.0"

pub fn main() {
  let start_time = timestamp.system_time()

  // Use the build time timestamp seconds as a hash for asset file names.
  // This allows extra-long caching while ensuring we never serve out-of-date assets.
  let hash =
    start_time
    |> timestamp.to_unix_seconds
    |> float.round
    |> int.to_string

  io.println(ansi.green("[Wisp]") <> " Building static docs site...")
  // Create the dist directory. We void the error here because it's fine if
  // the directory already exists.
  let _ = simplifile.create_directory("./dist")

  // Clear the dist directory so it's ready for our newly built files.
  let assert Ok(_) = simplifile.clear_directory("./dist")

  io.println(ansi.green("✓") <> " Cleared and created dist directory")

  io.println(ansi.green("✓") <> " Building output CSS file")
  let assert Ok(static_asset_files) = simplifile.read_directory("./assets")

  // Wastefully run lustre dev tools to build CSS
  // TODO: Find a cheaper way of doing this.
  // let assert Ok(_) =
  //   shellout.command(
  //     "gleam",
  //     [
  //       "run",
  //       "-m",
  //       "lustre/dev",
  //       "build",
  //       "--outdir=tmpdist",
  //     ],
  //     ".",
  //     [],
  //   )
  // let assert Ok(_) =
  //   simplifile.copy(
  //     src: "./tmpdist/wisp_website.css",
  //     dest: "./dist/style-" <> hash <> ".css",
  //   )
  //
  // let assert Ok(_) = simplifile.delete("./tmpdist")

  let static_assets =
    list.map(static_asset_files, fn(asset) {
      let assert Ok(is_dir) = simplifile.is_directory("./assets/" <> asset)
      let assert Ok(_) =
        simplifile.copy(src: "./assets/" <> asset, dest: "./dist/" <> asset)

      #(asset, is_dir)
    })

  io.print(ansi.green("-") <> " Generating docs ")

  let guides =
    [GuideSection("Getting Started", "getting-started", [])]
    |> list.map(fn(category) {
      let assert Ok(files) =
        simplifile.read_directory("./content/" <> category.slug)

      // Create the output directory
      let assert Ok(_) =
        simplifile.create_directory_all("./dist/docs/" <> category.slug)

      let guides =
        list.map(files, fn(file_name) {
          let assert Ok(content) =
            simplifile.read("./content/" <> category.slug <> "/" <> file_name)
          let assert frontmatter.Extracted(option.Some(frontmatter), content) =
            frontmatter.extract(content)

          let assert Ok(frontmatter) = tom.parse(frontmatter)
          let assert Ok(title) = tom.get_string(frontmatter, ["title"])
          let assert Ok(description) =
            tom.get_string(frontmatter, ["description"])

          let slug = string.replace(file_name, ".djot", "")

          let document = jot.parse(content)
          let document =
            jot.Document(
              ..document,
              content: list.map(document.content, fn(item) {
                case item {
                  jot.Codeblock(language: option.Some("gleam"), content:, ..) ->
                    jot.RawBlock(
                      "<pre><code>"
                      <> contour.to_html(content)
                      <> "</code></pre>",
                    )
                  _ -> item
                }
              }),
            )

          Guide(slug:, title:, description:, content: document)
        })

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
              title: guide.title,
              description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
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
          title: "Wisp: Build practical, performant, intuitive web applications with Gleam",
          description: "The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      #(
        "404.html",
        not_found(),
        Meta(
          title: "Page not found",
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      #(
        "docs/index.html",
        docs_index(guides),
        Meta(
          title: "Wisp Guides and Documentation",
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      ..guide_pages
    ]
    |> list.map(fn(page) {
      let #(path, view, meta) = page

      let html =
        layout(view, meta, hash)
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
  element.fragment([
    html.header([class("site-hero")], [
      site_nav(Home),

      html.div([class("text-center py-32")], [
        html.figure([class("mb-8 relative w-max mx-auto")], [
          html.img([
            attr.alt("Wisp Logo"),
            attr.src("/images/logo.svg"),
            class("mx-auto"),
          ]),
          html.span([class("version-label")], [
            html.text("v" <> version),
          ]),
        ]),
        html.p(
          [
            class("leading-relaxed max-w-[50ch] mx-auto font-dm-mono"),
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
}

fn docs_index(sections: List(GuideSection)) {
  element.fragment([
    html.header([class("site-hero")], [
      site_nav(DocsIndex),
      html.div([class("container")], [
        html.header([class("docs-header")], [
          html.h1([], [html.text("Guides")]),
          html.p([], [
            html.text(
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
              [html.text(section.title)],
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
                    html.h3([], [html.text(guide.title)]),
                    html.p([], [
                      html.text(guide.description),
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
  ])
}

fn doc_page(
  guides: List(GuideSection),
  section_name: String,
  title: String,
  content: jot.Document,
) {
  html.div([class("docs-layout")], [
    html.aside([class("docs-sidebar")], [
      html.a([href("/"), class("sidebar-logo")], [
        html.img([
          attr.src("/images/logo.svg"),
          attr.alt("Wisp"),
          class("h-10"),
        ]),
      ]),
      ..list.map(guides, fn(section) {
        html.nav([], [
          html.h5([], [html.text(section.title)]),
          html.ul(
            [],
            list.map(section.guides, fn(guide) {
              html.li([], [
                html.a([href("/docs/" <> section.slug <> "/" <> guide.slug)], [
                  html.text(guide.title),
                ]),
              ])
            }),
          ),
        ])
      })
    ]),
    html.main([class("container grid gap-4 lg:gap-8 lg:grid-cols-4")], [
      html.nav([class("site-nav lg:col-span-4")], [
        html.div([class("container")], [
          html.form([class("nav-search")], [
            html.input([
              attr.type_("text"),
              attr.placeholder("Search..."),
            ]),
          ]),
          html.ul([class("site-links ml-auto")], [
            html.li([], [
              html.a([href("/docs")], [
                guide_icon([class("size-5")]),
                html.text("Guides"),
              ]),
            ]),
            html.li([], [
              html.a([href("https://github.com/gleam-wisp/wisp")], [
                source_icon([class("size-5")]),
                html.text("Source"),
              ]),
            ]),
            html.li([], [
              html.a([href("https://wisp.hexdocs.pm/")], [
                hexdocs_icon([class("size-5")]),
                html.text("HexDocs"),
              ]),
            ]),
            html.li([class("special-link")], [
              html.a([href("https://github.com/lpil")], [
                heart_icon([class("size-5")]),
                html.text("Sponsor"),
              ]),
            ]),
          ]),
        ]),
      ]),

      html.header([class("docs-header lg:col-span-4")], [
        html.h4([], [html.text(section_name)]),
        html.h1([], [html.text(title)]),
      ]),

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
            html.li([], [html.text("On this page")]),
            ..list.map(
              page_contents_from_markup(option.Some(demo.post_content())),
              fn(title) {
                html.li([], [
                  html.a([href("#" <> title.1)], [
                    html.text(title.0),
                  ]),
                ])
              },
            )
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
      site_nav(Home),

      html.div([class("text-center py-32")], [
        html.figure([class("mb-8 relative w-max mx-auto")], [
          html.img([
            attr.alt("Wisp Logo"),
            attr.src("/images/logo.svg"),
            class("mx-auto"),
          ]),
          html.span([class("version-label")], [
            html.text("v" <> version),
          ]),
        ]),
        html.h1([class("font-bold text-3xl mb-3")], [
          html.text("Page not found"),
        ]),
        html.p(
          [
            class("leading-relaxed max-w-[50ch] mx-auto"),
          ],
          [
            html.text(
              "Sorry! It looks like the page you were looking for could not be found. Check the address bar to see if there is a clear mistake, or ",
            ),
            html.a(
              [
                href("/"),
                class("underline decoration-brand-prime font-medium"),
              ],
              [
                html.text("return home"),
              ],
            ),
          ],
        ),
      ]),
    ]),
    site_footer(2026, []),
  ])
}

fn layout(
  body: element.Element(a),
  meta: Meta,
  asset_hash: String,
) -> element.Element(a) {
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
        attr.href("favicon.ico"),
        attr.rel("icon"),
        attr.type_("image/svg"),
      ]),
      html.link([attr.href("icon.svg"), attr.rel("apple-touch-icon")]),
      html.meta([
        attr("content", meta.description),
        attr.name("description"),
      ]),
      html.meta([
        attr("content", "My Web Project"),
        attr("property", "og:title"),
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
        attr("content", "icon.png"),
        attr("property", "og:image"),
      ]),
      html.link([
        attr.rel("stylesheet"),
        attr.href("/style-" <> asset_hash <> ".css"),
      ]),
    ]),
    html.body([], [body]),
  ])
}

pub type Route {
  Home
  DocsIndex
  DocPage(slug: String, content: option.Option(jot.Document))
  NotFound
}

pub type GuideSection {
  GuideSection(title: String, slug: String, guides: List(Guide))
}

pub type Guide {
  Guide(slug: String, title: String, description: String, content: jot.Document)
}

pub type Model {
  Model(guides: List(GuideSection), route: Route)
}

fn site_nav(_current: Route) {
  html.nav([class("site-nav")], [
    html.div([class("container")], [
      html.a([href("/"), class("site-logo")], [
        html.img([
          attr.src("/images/logo.svg"),
          attr.alt("Wisp logo"),
          class("h-12"),
        ]),
      ]),
      html.ul([class("site-links")], [
        html.li([], [
          html.a([href("/docs")], [
            guide_icon([class("size-5")]),
            html.text("Guides"),
          ]),
        ]),
        html.li([], [
          html.a([href("https://github.com/gleam-wisp/wisp")], [
            source_icon([class("size-5")]),
            html.text("Source"),
          ]),
        ]),
        html.li([], [
          html.a([href("https://wisp.hexdocs.pm/")], [
            hexdocs_icon([class("size-5")]),
            html.text("HexDocs"),
          ]),
        ]),
        html.li([class("special-link")], [
          html.a([href("https://github.com/lpil")], [
            heart_icon([class("size-5")]),
            html.text("Sponsor"),
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
          html.text(
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
            [html.text("Code of Conduct")],
          ),
        ]),
      ],
    ),
  ])
}

fn guide_icon(attrs) {
  svg.svg(
    [
      attr("xmlns", "http://www.w3.org/2000/svg"),
      attr("fill", "none"),
      attr("viewBox", "0 0 14 18"),
      ..attrs
    ],
    [
      svg.mask([attr("fill", "white"), attr.id("path-1-inside-1_542_330")], [
        svg.rect([
          attr("rx", "1"),
          attr("height", "16"),
          attr("width", "14"),
        ]),
      ]),
      svg.rect([
        attr("mask", "url(#path-1-inside-1_542_330)"),
        attr("stroke-width", "4"),
        attr("stroke", "currentColor"),
        attr("rx", "1"),
        attr("height", "16"),
        attr("width", "14"),
      ]),
      svg.mask([attr("fill", "white"), attr.id("path-2-inside-2_542_330")], [
        svg.rect([
          attr("rx", "1"),
          attr("height", "5"),
          attr("width", "14"),
          attr("y", "11"),
        ]),
      ]),
      svg.rect([
        attr("mask", "url(#path-2-inside-2_542_330)"),
        attr("stroke-width", "4"),
        attr("stroke", "currentColor"),
        attr("rx", "1"),
        attr("height", "5"),
        attr("width", "14"),
        attr("y", "11"),
      ]),
      svg.path([
        attr("fill", "currentColor"),
        attr(
          "d",
          "M3 13H7V17C7 17.5523 6.55228 18 6 18H4C3.44772 18 3 17.5523 3 17V13Z",
        ),
      ]),
      svg.path([
        attr("stroke-linecap", "round"),
        attr("stroke-width", "2"),
        attr("stroke", "currentColor"),
        attr("d", "M4 5H10M4 8H6H8"),
      ]),
    ],
  )
}

fn source_icon(attrs) {
  svg.svg(
    [
      attr("xmlns", "http://www.w3.org/2000/svg"),
      attr("fill", "none"),
      attr("viewBox", "0 0 20 14"),
      ..attrs
    ],
    [
      svg.path([
        attr("stroke-linecap", "round"),
        attr("stroke-width", "2"),
        attr("stroke", "currentColor"),
        attr(
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
      attr("xmlns", "http://www.w3.org/2000/svg"),
      attr("fill", "none"),
      attr("viewBox", "0 0 16 19"),
      ..attrs
    ],
    [
      svg.path([
        attr("stroke-width", "2"),
        attr("stroke", "currentColor"),
        attr(
          "d",
          "M7.48926 1.46582C7.80397 1.27896 8.19603 1.27896 8.51074 1.46582L14.5107 5.02832C14.8142 5.20849 15 5.53577 15 5.88867V13.1113C15 13.4642 14.8142 13.7915 14.5107 13.9717L8.51074 17.5342C8.19603 17.721 7.80397 17.721 7.48926 17.5342L1.48926 13.9717C1.18582 13.7915 1 13.4642 1 13.1113V5.88867L1.00879 5.75781C1.04849 5.45631 1.2237 5.18601 1.48926 5.02832L7.48926 1.46582Z",
        ),
      ]),
      svg.path([
        attr("stroke-linecap", "round"),
        attr("stroke-width", "2"),
        attr("stroke", "currentColor"),
        attr("d", "M5 8H11M5 11.5H7H9"),
      ]),
    ],
  )
}

fn heart_icon(attrs) {
  svg.svg(
    [
      attr("xmlns", "http://www.w3.org/2000/svg"),
      attr("fill", "none"),
      attr("viewBox", "0 0 18 16"),
      ..attrs
    ],
    [
      svg.path([
        attr("stroke-width", "2"),
        attr("stroke", "currentColor"),
        attr(
          "d",
          "M10.3984 2.14062C11.9088 0.619762 14.3542 0.619812 15.8643 2.14062C17.3785 3.66575 17.3785 6.14187 15.8643 7.66699L9 14.5801L2.13574 7.66699C0.621774 6.14191 0.621774 3.6657 2.13574 2.14062C3.64603 0.619854 6.09148 0.619892 7.60156 2.14062L8.29004 2.83398L9 3.54883L9.70996 2.83398L10.3984 2.14062Z",
        ),
      ]),
    ],
  )
}

fn page_contents_from_markup(
  document: option.Option(jot.Document),
) -> List(#(String, String)) {
  case document {
    option.Some(jot.Document(content:, ..)) ->
      list.fold(content, [], fn(acc, container) {
        case container {
          jot.Heading(level:, content: [jot.Text(title)], attributes:)
            if level == 1 || level == 3 || level == 2
          -> {
            let href = dict.get(attributes, "id") |> result.unwrap("unknown")
            // let href = d(attrs, "id")
            [#(title, href), ..acc]
          }
          _ -> acc
        }
      })
    option.None -> []
  }
  |> list.reverse()
}
