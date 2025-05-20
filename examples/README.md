# Wisp Examples

For each example, you have its respective [module name](https://tour.gleam.run/basics/modules/).
You can find the source associated to the example under `./src/$MODULE_NAME`,
and its tests under `./test/$MODULE_NAME`.

To run an example, you can run the following:

```sh
# replace $MODULE_NAME with the name of the module associated to each example
gleam run -m $MODULE_NAME/app
```

To run the tests, do the following:

```sh
gleam test
```

If you would like to use these tests in your project, make sure to change the
`app` keyword to the name of your project.

## Examples

Here is a list of all the examples and their associated module name (formatted
"`$MODULE_NAME` - Example title"):

- [`hello_world` - Hello, World!](./src/hello_world)
- [`routing` - Routing](./src/routing)
- [`working_with_form_data` - Working with form data](./src/working_with_form_data)
- [`working_with_json` - Working with JSON](./src/working_with_json)
- [`working_with_other_formats` - Working with other formats](./src/working_with_other_formats)
- [`using_a_database` - Using a database](./src/using_a_database)
- [`serving_static_assets` - Serving static assets](./src/serving_static_assets)
- [`logging` - Logging](./src/logging)
- [`working_with_cookies` - Working with cookies](./src/working_with_cookies)
- [`configuring_default_responses` - Configuring default responses](./src/configuring_default_responses)
- [`working_with_files` - Working with files](./src/working_with_files)
