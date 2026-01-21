![wisp_ewe](https://github.com/lpil/wisp/blob/main/wisp_ewe/cover.jpg?raw=true)

# wisp_ewe

[![Package Version](https://img.shields.io/hexpm/v/wisp_ewe)](https://hex.pm/packages/wisp_ewe)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/wisp_ewe/)

An Ewe adapter for Wisp.

```sh
gleam add wisp_ewe
```

## Example

```gleam
pub fn main() -> Nil {
  let secret_key_base = "..."
  let assert Ok(_) =
    handle_request
    |> wisp_ewe.handler(secret_key_base)
    |> ewe.new
    |> ewe.listening(port: 8000)
    |> ewe.start
  process.sleep_forever()
}
```
