import gleam/otp/actor
import wisp/internal/supervisor

const db_config = "postgresql://..."

const ampq = "ampq://..."

//
// There are 3 children:
// 1. Database
// 2. Job queue
// 3. HTTP server
//
// Database depends on:
// - a static database configuratation string
//
// Job queue depends on:
// - a static queue configuratation string
// - a reference to the running database
//
// HTTP server depends on:
// - a reference to the running database
// - a reference to the running work queue
//

pub fn using() {
  supervisor.new(fn() {
    use database <- supervisor.add(database_spec(db_config))
    use job_queue <- supervisor.add(job_queue_spec(database, ampq))
    use _http <- supervisor.add(http_server_spec(database, job_queue))
    supervisor.ready()
  })
}

// helpers

pub type Database

fn database_spec(_config: String) -> supervisor.Template(String, Database) {
  todo
}

pub type JobQueue

pub type JobConfiguration {
  JobQueueConfiguration(database: Database, ampq: String)
}

fn job_queue_spec(
  config: JobConfiguration,
) -> supervisor.Template(JobConfiguration, JobQueue) {
  todo
}

pub type ServerFlags {
  ServerFlags(database: Database, job_queue: JobQueue)
}

pub type HttpServer

fn http_server_spec(
  database: Database,
) -> supervisor.Template(Database, HttpServer) {
  todo
}
