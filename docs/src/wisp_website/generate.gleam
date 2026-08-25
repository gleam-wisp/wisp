import contour
import frontmatter
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam_community/ansi
import jot
import lustre/attribute.{attribute}
import lustre/element
import lustre/element/html
import shellout
import simplifile
import tom
import wisp_website.{DocPage, DocsIndex, GuideSection, Home, Model, NotFound}

type Meta {
  Meta(title: String, description: String)
}

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
  let assert Ok(_) =
    shellout.command(
      "gleam",
      [
        "run",
        "-m",
        "lustre/dev",
        "build",
        "--outdir=tmpdist",
      ],
      ".",
      [],
    )
  let assert Ok(_) =
    simplifile.copy(
      src: "./tmpdist/wisp_website.css",
      dest: "./dist/style-" <> hash <> ".css",
    )

  let assert Ok(_) = simplifile.delete("./tmpdist")

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
        simplifile.create_directory_all("./dist/docs" <> category.slug)

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

          wisp_website.Guide(
            slug:,
            title:,
            description:,
            content: option.Some(document),
          )
        })

      GuideSection(..category, guides:)
    })

  let guide_pages =
    list.fold(guides, [], fn(acc, section) {
      list.fold(section.guides, acc, fn(acc, guide) {
        [
          #(
            "docs/" <> section.slug <> "/" <> guide.slug <> ".html",
            Model(guides, DocPage(slug: guide.slug, content: guide.content)),
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
        Model(guides, Home),
        Meta(
          title: "Wisp: Build practical, performant, intuitive web applications with Gleam",
          description: "The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      #(
        "404.html",
        Model(guides, NotFound),
        Meta(
          title: "Page not found",
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      #(
        "docs/index.html",
        Model(guides, DocsIndex),
        Meta(
          title: "Wisp Guides and Documentation",
          description: "Wisp: The go-to web server framework for Gleam, from beginners to scale.",
        ),
      ),
      ..guide_pages
    ]
    |> list.map(fn(page) {
      let #(path, model, meta) = page

      let html =
        wisp_website.view(model)
        |> layout(meta, hash)
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

fn layout(
  body: element.Element(a),
  meta: Meta,
  asset_hash: String,
) -> element.Element(a) {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.meta([attribute("charset", "UTF-8")]),
      html.meta([
        attribute("content", "width=device-width, initial-scale=1.0"),
        attribute.name("viewport"),
      ]),
      html.meta([
        attribute("content", "ie=edge"),
        attribute("http-equiv", "X-UA-Compatible"),
      ]),
      html.title([], meta.title),
      html.link([
        attribute.href("favicon.ico"),
        attribute.rel("icon"),
        attribute.type_("image/svg"),
      ]),
      html.link([attribute.href("icon.svg"), attribute.rel("apple-touch-icon")]),
      html.meta([
        attribute("content", meta.description),
        attribute.name("description"),
      ]),
      html.meta([
        attribute("content", "My Web Project"),
        attribute("property", "og:title"),
      ]),
      html.meta([
        attribute("content", "website"),
        attribute("property", "og:type"),
      ]),
      html.meta([
        attribute("content", "https://gleam-wisp.github.io/wisp/"),
        attribute("property", "og:url"),
      ]),
      html.meta([
        attribute("content", "icon.png"),
        attribute("property", "og:image"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/style-" <> asset_hash <> ".css"),
      ]),
    ]),
    html.body([], [body]),
  ])
}
