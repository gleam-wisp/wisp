import lustre/attribute
import lustre/element
import lustre/element/html
import wisp_website

pub fn main() {
  wisp_website.view(wisp_website.Home)
  |> element.to_document_string
  |> echo
}

fn layout() {
  html.html([attribute.lang("en")], [])
}
