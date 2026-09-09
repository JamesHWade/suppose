.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    record = if (file.exists("artifacts/sensitivity/browser-saved.json")) {
      "artifacts/sensitivity/browser-saved.json"
    } else {
      "artifacts/sensitivity/ready.json"
    },
    agent_factory = suppose_agent,
    history_dir = ".suppose/sensitivity-acceptance-history"
  ),
  host = "127.0.0.1",
  port = 3902,
  launch.browser = FALSE
)
