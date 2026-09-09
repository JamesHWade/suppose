.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = "artifacts/bed-conversation.json",
    agent_factory = suppose_agent,
    history_dir = ".suppose/research-loop-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3914,
  launch.browser = FALSE
)
