# wisp_mist

[![Package Version](https://img.shields.io/hexpm/v/wisp_mist)](https://hex.pm/packages/wisp_mist)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/wisp_mist/)

A Mist adapter for Wisp.

```sh
gleam add wisp_mist
```

## Example

```gleam
pub fn main() -> Nil {
  let secret_key_base = "..."
  let assert Ok(_) =
    handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start
  process.sleep_forever()
}
```
