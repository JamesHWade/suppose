.libPaths(c(normalizePath('.suppose/runtime-library'), .libPaths()))
pkgload::load_all(quiet = TRUE)
shiny::runApp(
  suppose_app(model = suppose_model_example('linear'), history_dir = NULL),
  host = '127.0.0.1',
  port = 3915,
  launch.browser = FALSE
)
