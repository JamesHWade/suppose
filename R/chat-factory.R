inquiry_chat_factory <- function(chat) {
  if (is.function(chat)) {
    return(function() {
      client <- chat()
      if (!inherits(client, "Chat")) {
        abort_suppose(
          "The chat constructor must return an ellmer Chat.",
          "chat"
        )
      }
      client
    })
  }
  if (!inherits(chat, "Chat")) {
    abort_suppose(
      "Supply an ellmer Chat or a function that creates one.",
      "chat"
    )
  }
  rlang::check_installed("ellmer", version = "0.5.0")
  # Reconstruct from public configuration instead of copying callback closures
  # or a previously used conversation. Capture configuration at app creation.
  provider <- chat$get_provider()
  model <- chat$get_model_object()
  function() ellmer::Chat$new(provider = provider, model = model, echo = "none")
}
