# Requires python3 dev/inquiry-fixture-server.py in another terminal.
# This exercises the real Deputy Agent and shinychat against a scripted server.
pkgload::load_all(quiet = TRUE)
factory <- function() {
  suppose_agent(ellmer::chat_openai_compatible(
    base_url = "http://127.0.0.1:3893/v1",
    model = "local-inquiry-fixture",
    credentials = function() "fixture",
    echo = "none"
  ))
}
shiny::runApp(
  suppose_app(agent_factory = factory),
  host = "127.0.0.1",
  port = 3894,
  launch.browser = FALSE
)
