# Local, credential-free P0 browser fixtures. Run from the package root.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
args <- commandArgs(TRUE)
mode <- if (length(args)) args[1] else "manual"
port <- if (length(args) > 1) as.integer(args[2]) else 3905L
x <- if (mode == "example") suppose_example(accept = TRUE) else NULL
factory <- NULL
if (mode %in% c("fixture", "unavailable")) {
  factory <- function() {
    suppose_agent(ellmer::chat_openai_compatible(
      base_url = if (mode == "fixture") {
        "http://127.0.0.1:3907/v1"
      } else {
        "http://127.0.0.1:0/v1"
      },
      model = "local-inquiry-fixture",
      credentials = function() "fixture",
      echo = "none"
    ))
  }
}
shiny::runApp(
  if (mode == "numeric") {
    suppose_example_app()
  } else {
    suppose_app(record = x, agent_factory = factory, history_dir = NULL)
  },
  host = "127.0.0.1",
  port = port,
  launch.browser = FALSE
)
