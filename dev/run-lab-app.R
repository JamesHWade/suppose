# Reopen the local lab demonstrations with the same native conversation store.
if (dir.exists(".suppose/runtime-library")) {
  .libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
}
pkgload::load_all(quiet = TRUE)
if (!nzchar(Sys.getenv("OPENROUTER_API_KEY"))) {
  stop(
    "Configure OPENROUTER_API_KEY locally before opening the lab conversations."
  )
}
if (dir.exists("artifacts/visualizations")) {
  shiny::addResourcePath(
    "visualization-examples",
    normalizePath("artifacts/visualizations")
  )
}
shiny::runApp(
  suppose_app(agent_factory = suppose_agent),
  host = "127.0.0.1",
  port = 3899,
  launch.browser = interactive()
)
