pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    agent_factory = suppose_agent,
    history_dir = "artifacts/cards-qa-history"
  ),
  host = "127.0.0.1",
  port = 3900,
  launch.browser = FALSE
)
