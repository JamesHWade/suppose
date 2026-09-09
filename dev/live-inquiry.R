# Opt-in live check of the chat-first Deputy path using synthetic inputs.
# Contributor prompts/outputs may be used by Meta for training.
pkgload::load_all(quiet = TRUE)
if (!nzchar(Sys.getenv("OPENROUTER_API_KEY"))) {
  stop("Configure OPENROUTER_API_KEY locally before running this live check.")
}
first <- "I think fewer recurring meetings could help our team finish work sooner. Help me clarify what I mean."
x <- elicitation_record(claim(first, "Demo reviewer"), "Synthetic live inquiry")
s <- suppose:::new_proposal_session(
  function() x,
  general = TRUE,
  model = "meta/muse-spark-1.3-contributor",
  provider = "deputy"
)
agent <- suppose_agent()
for (message in c(
  first,
  "By finish sooner I mean elapsed days from starting to completing a work item, for our team next quarter. I assume coordination quality stays unchanged. Please propose a reviewable interpretation, keeping unestablished facts as assumptions or open questions. No numerical model is needed."
)) {
  id <- s$begin(message)
  agent$set_tools(s$tools(id))
  response <- agent$chat(message)
  stopifnot(deputy::result_is_success(agent$last_run()))
  s$finish(id, response, execution = suppose:::deputy_run_receipt(agent))
  cat("\nUSER:", message, "\nASSISTANT:", response, "\n")
}
p <- s$pending
stopifnot(!is.null(p), is.null(p$candidate), !is.null(p$claim$target))
# Explicit synthetic review by the test harness, not by the model.
x <- apply_assistant_proposal(x, p, "Demo reviewer")
x <- accept_interpretation(
  x,
  "Demo reviewer",
  "Synthetic semantic review",
  "Delivery time rises or coordination quality worsens"
)
x <- suppose:::record_conversation(x, s$messages)
path <- tempfile("suppose-live-inquiry-", fileext = ".json")
write_record(x, path)
stopifnot(identical(
  suppose:::json_data(x),
  suppose:::json_data(read_record(path))
))
cat("\nSynthetic live inquiry saved and reopened:", path, "\n")
