import directories
import gleam/bit_array
import gleam/crypto
import gleam/string

// HELPERS

//
// Requests
//

/// The connection to the client for a HTTP request.
///
/// The body of the request can be read from this connection using functions
/// such as `require_multipart_body`.
///
pub type Connection {
  Connection(
    reader: Reader,
    max_body_size: Int,
    max_files_size: Int,
    read_chunk_size: Int,
    secret_key_base: String,
    temporary_directory: String,
  )
}

pub fn make_connection(
  body_reader: Reader,
  secret_key_base: String,
) -> Connection {
  // Fallback to current working directory when no valid tmp directory exists
  let prefix = case directories.tmp_dir() {
    Ok(tmp_dir) -> tmp_dir <> "/gleam-wisp/"
    Error(_) -> "./tmp/"
  }
  let temporary_directory = join_path(prefix, random_slug())
  Connection(
    reader: body_reader,
    max_body_size: 8_000_000,
    max_files_size: 32_000_000,
    read_chunk_size: 1_000_000,
    temporary_directory: temporary_directory,
    secret_key_base: secret_key_base,
  )
}

type Reader =
  fn(Int) -> Result(Read, Nil)

pub type Read {
  Chunk(BitArray, next: Reader)
  ReadingFinished
}

//
// Middleware Helpers
//

pub fn remove_preceeding_slashes(string: String) -> String {
  case string {
    "/" <> rest -> remove_preceeding_slashes(rest)
    _ -> string
  }
}

// TODO: replace with simplifile function when it exists
pub fn join_path(a: String, b: String) -> String {
  let b = remove_preceeding_slashes(b)
  case string.ends_with(a, "/") {
    True -> a <> b
    False -> a <> "/" <> b
  }
}

//
// Cryptography
//

/// Generate a random string of the given length.
///
pub fn random_string(length: Int) -> String {
  crypto.strong_random_bytes(length)
  |> bit_array.base64_url_encode(False)
  |> string.slice(0, length)
}

pub fn random_slug() -> String {
  random_string(16)
}
