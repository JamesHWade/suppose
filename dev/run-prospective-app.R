.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = if (file.exists("artifacts/prospective/browser-saved.json")) {
      "artifacts/prospective/browser-saved.json"
    } else {
      "artifacts/prospective/ready.json"
    },
    agent_factory = suppose_agent,
    history_dir = ".suppose/prospective-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3901,
  launch.browser = FALSE
)
