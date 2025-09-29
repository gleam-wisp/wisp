import gleam/bytes_tree
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import wisp.{type Request, type Response}
import working_with_files/app/web

pub fn handle_request(req: Request) -> Response(_) {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> show_home(req)
    ["file-from-disc"] -> handle_download_file_from_disc(req)
    ["file-from-memory"] -> handle_download_file_from_memory(req)
    ["upload-file"] -> handle_file_upload(req)
    _ -> wisp.not_found()
  }
}

// Notice how `enctype="multipart/form-data"` is used in the file-upload form.
// This ensure that the file is encoded appropriately for the server to read.
const html = "
<p><a href='/file-from-memory'>Download file from memory</a></p>
<p><a href='/file-from-disc'>Download file from disc</a></p>

<form method=post action='/upload-file' enctype='multipart/form-data'>
  <label>Your file:
    <input type='file' name='uploaded-file'>
  </label>
  <input type='submit' value='Submit'>
</form>
"

fn show_home(req: Request) -> Response(_) {
  use <- wisp.require_method(req, Get)
  html
  |> wisp.html_response(200)
}

fn handle_download_file_from_memory(req: Request) -> Response(_) {
  use <- wisp.require_method(req, Get)

  // In this case we have the file contents in memory as a string.
  // This is good if we have just made the file, but if the file already exists
  // on the disc then the approach in the next function is more efficient.
  let file_contents = bytes_tree.from_string("Hello, Joe!")

  wisp.ok()
  |> wisp.set_header("content-type", "text/plain")
  // The content-disposition header is set by this function to ensure this is
  // treated as a file download. If the file was uploaded by the user then you
  // want to ensure that this header is set as otherwise the browser may try to
  // display the file, which could enable cross-site scripting attacks.
  |> wisp.file_download_from_memory(
    named: "hello.txt",
    containing: file_contents,
  )
}

fn handle_download_file_from_disc(req: Request) -> Response(_) {
  use <- wisp.require_method(req, Get)

  // In this case the file exists on the disc.
  // Here we're using the project gleam.toml, but in a real application you'd
  // probably have an absolute path to wherever it is you keep your files.
  let file_path = "./gleam.toml"

  wisp.ok()
  |> wisp.set_header("content-type", "text/markdown")
  |> wisp.file_download(named: "hello.md", from: file_path)
}

fn handle_file_upload(req: Request) -> Response(_) {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  // The list and result module are used here to extract the values from the
  // form data.
  // Alternatively you could also pattern match on the list of values (they are
  // sorted into alphabetical order), or use a HTML form library.
  let result = {
    // Note the name of the input is used to find the value.
    use file <- result.try(list.key_find(formdata.files, "uploaded-file"))

    // The file has been streamed to a temporary file on the disc, so there's no
    // risk of large files causing memory issues.
    // The `.path` field contains the path to this file, which you may choose to
    // move or read using a library like `simplifile`. When the request is done the
    // temporary file is deleted.
    wisp.log_info("File uploaded to " <> file.path)

    // File uploads may include a file name. Some clients such as curl may not
    // have one, so this field may be empty.
    // You should never trust this field. Just because it has a particular file
    // extension does not mean it is a file of that type, and it may contain
    // invalid characters. Always validate the file type and do not use this
    // name as the new path for the file.
    wisp.log_info("The file name is reportedly " <> file.file_name)

    // Once the response has been sent the uploaded file will be deleted. If
    // you want to retain the file then move it to a new location.

    Ok(file.file_name)
  }

  // An appropriate response is returned depending on whether the form data
  // could be successfully handled or not.
  case result {
    Ok(name) -> {
      { "<p>Thank you for your file `" <> name <> "`</p>" <> html }
      |> wisp.html_response(200)
    }
    Error(_) -> {
      wisp.bad_request("File missing")
    }
  }
}
