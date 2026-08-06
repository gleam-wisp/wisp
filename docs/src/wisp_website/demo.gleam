import jot

// ---
// title = \"Testing out\"
// published = \"2020-03-04\"
// updated = \"2020-03-04\"
// order = 1
// ---

const test_djot_input = "## Hello Joe!

Hey :)

```gleam
pub fn main() {
  echo \"Hello world!\"
}
```

## Wibble 

Wibble!

### Wobble

Wobble!"

pub fn post_content() -> jot.Document {
  jot.parse(test_djot_input)
}
