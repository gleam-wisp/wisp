import gleam/http
import gleam/int
import gleam/string
import promgleam/metrics/counter.{create_counter, increment_counter}
import promgleam/metrics/histogram.{create_histogram, observe_histogram}
import promgleam/registry.{print_as_text}
import promgleam/utils.{measure}
import wisp

const registy_name = "default"

const http_requests_total = "http_requests_total"

const http_request_duration_seconds = "http_request_duration_seconds"

/// This creates a `http_requests_total` [Counter](https://prometheus.io/docs/concepts/metric_types/#counter)
/// and a `http_request_duration_seconds` [Histogram](https://prometheus.io/docs/concepts/metric_types/#histogram).
/// This is called in the entrypoint (`app.gleam`) to initialise these metrics before the server starts.
pub fn create_standard_metrics() {
  let assert Ok(_) =
    create_counter(
      registry: registy_name,
      name: http_requests_total,
      help: "Total number of HTTP requests",
      labels: ["method", "route", "status"],
    )

  let assert Ok(_) =
    create_histogram(
      registry: registy_name,
      name: http_request_duration_seconds,
      help: "Duration of HTTP requests in seconds",
      labels: ["method", "route", "status"],
      // OpenTelemetry recommendation for histogram buckets of http request duration:
      // https://opentelemetry.io/docs/specs/semconv/http/http-metrics/#metric-httpserverrequestduration
      buckets: [
        0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0,
        7.5, 10.0,
      ],
    )

  Nil
}

/// This middleware is used in the main middleware chain (`app/web.gleam`). This executes the route handler
/// while measuring its executing time, then records that in the `http_requests_total` and
/// `http_request_duration_seconds` metrics.
pub fn record_http_metrics(
  req: wisp.Request,
  handle_request: fn() -> wisp.Response,
) -> wisp.Response {
  let route_name = get_route_name(req)
  let #(time_taken, response) = measure(handle_request)
  let time_taken_in_seconds = int.to_float(time_taken) /. 1000.0
  let method = string.uppercase(http.method_to_string(req.method))

  let assert Ok(_) =
    increment_counter(
      registry: registy_name,
      name: http_requests_total,
      labels: [method, route_name, int.to_string(response.status)],
      value: 1,
    )

  let assert Ok(_) =
    observe_histogram(
      registry: registy_name,
      name: http_request_duration_seconds,
      labels: [method, route_name, int.to_string(response.status)],
      value: time_taken_in_seconds,
    )

  response
}

/// This handler returns the metrics in the Prometheus text format.
/// This is exposed on the `/metrics` route in `app/router.gleam`.
pub fn print_metrics(req: wisp.Request) -> wisp.Response {
  // The metrics endpoint can only be accessed via GET requests.
  use <- wisp.require_method(req, http.Get)

  let body = print_as_text(registy_name)

  wisp.ok()
  |> wisp.string_body(body)
}

/// This is an internal function which is used to generate the `route` label for requests.
/// It's recommended to group the requests by some sort of request patterns (e.g. `/comments/:id`)
/// instead of using the request path directly.
fn get_route_name(req: wisp.Request) -> String {
  case wisp.path_segments(req) {
    [] -> "/"
    ["comments"] -> "/comments"
    ["comments", _] -> "/comments:id"
    ["metrics"] -> "/metrics"
    _ -> req.path
  }
}
