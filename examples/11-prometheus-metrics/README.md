# Wisp Example: Prometheus metrics

```sh
gleam run   # Run the server
gleam test  # Run the tests
```

This example shows how to add HTTP instrumentation using [Prometheus](https://prometheus.io/docs/introduction/overview/)
metrics to measure response times and count incoming requests per route and status code.

This example is based off of the ["routing" example][routing], so read that
one first. The additions are detailed here and commented in the code.

[routing]: https://github.com/lpil/wisp/tree/main/examples/01-routing

### How to test

1. Run this example with `gleam run`
2. Open some pages, e.g. [/comments/1](http://localhost:8000/comments/1)
2. Check the metrics printed at [/metrics](http://localhost:8000/metrics)

### `app/metrics` module

This contains the logic for instrumentation:
#### `create_standard_metrics()`

This creates a `http_requests_total` [Counter](https://prometheus.io/docs/concepts/metric_types/#counter)
and a `http_request_duration_seconds` [Histogram](https://prometheus.io/docs/concepts/metric_types/#histogram).

This is called in the entrypoint (`app.gleam`) to initialise these metrics before the server starts.

#### `record_http_metrics(Request) -> Response`

This middleware is used in the main middleware chain (`app/web.gleam`). This executes the route handler while measuring its
executing time, then records that in the `http_requests_total` and `http_request_duration_seconds` metrics.

#### `print_metrics(Request) -> Response`

This handler returns the metrics in the Prometheus text format. This is exposed on the `/metrics` route in `app/router.gleam`.

#### `get_route_name(Request) -> String`

This is an internal function which is used to generate the `route` label for requests. It's recommended to group the requests
by some sort of request patterns (e.g. `/comments/:id`) instead of using the request path directly.
