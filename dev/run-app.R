pkgload::load_all(quiet = TRUE)
factory <- if (nzchar(Sys.getenv("OPENROUTER_API_KEY"))) suppose_agent else NULL
shiny::runApp(
  suppose_app(agent_factory = factory),
  host = "127.0.0.1",
  port = 3891,
  launch.browser = interactive()
)
