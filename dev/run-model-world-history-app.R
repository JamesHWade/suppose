.libPaths(c(normalizePath('.suppose/runtime-library'), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(
    model = suppose_model_example('linear'),
    agent_factory = suppose_agent,
    history_dir = '.suppose/model-world-acceptance-history'
  ),
  host = '127.0.0.1',
  port = 3916,
  launch.browser = FALSE
)
