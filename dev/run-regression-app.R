.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = "artifacts/regression/ready.json",
    agent_factory = suppose_agent,
    history_dir = ".suppose/regression-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3904,
  launch.browser = FALSE
)
