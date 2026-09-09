.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = "artifacts/plantgrowth/prior-and-data.json",
    agent_factory = function() suppose_agent(bundles = "r"),
    history_dir = ".suppose/plantgrowth-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3900,
  launch.browser = FALSE
)
