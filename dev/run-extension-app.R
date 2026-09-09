.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = "artifacts/extension/ready.json",
    agent_factory = suppose_agent,
    history_dir = ".suppose/extension-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3903,
  launch.browser = FALSE
)
