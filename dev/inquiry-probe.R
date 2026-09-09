# Requires dev/inquiry-fixture-server.py. Exercises real Deputy execution.
pkgload::load_all(quiet = TRUE)
first <- "I think fewer meetings would help our team finish work sooner."
x <- elicitation_record(claim(first, "Demo reviewer"), "Team inquiry fixture")
s <- suppose:::new_proposal_session(
  function() x,
  general = TRUE,
  model = "local-inquiry-fixture",
  provider = "deputy"
)
agent <- suppose_agent(ellmer::chat_openai_compatible(
  base_url = "http://127.0.0.1:3893/v1",
  model = "local-inquiry-fixture",
  credentials = function() "fixture",
  echo = "none"
))
for (message in c(
  first,
  "By finish sooner I mean elapsed days from starting to completing a work item, next quarter. Keep coordination quality unchanged."
)) {
  id <- s$begin(message)
  agent$set_tools(s$tools(id))
  response <- agent$chat(message)
  stopifnot(deputy::result_is_success(agent$last_run()))
  s$finish(id, response, execution = suppose:::deputy_run_receipt(agent))
}
stopifnot(
  is.null(s$pending$candidate),
  s$pending$claim$horizon == "Next quarter"
)
x <- apply_assistant_proposal(x, s$pending, "Demo reviewer")
x <- accept_interpretation(
  x,
  "Demo reviewer",
  "Matches the intended question",
  "Delivery time rises or coordination quality worsens"
)
x <- suppose:::record_conversation(x, s$messages)
write_record(x, "artifacts/inquiry-record.json", overwrite = TRUE)
stopifnot(identical(
  suppose:::json_data(x),
  suppose:::json_data(read_record("artifacts/inquiry-record.json"))
))
cat(
  "Real Deputy Agent; local scripted model protocol, no external inference.\n"
)
cat(
  "Two governed conversations completed, correction retained, interpretation accepted without a numerical model.\n"
)
cat("Saved and reopened four messages and two Deputy run receipts.\n")
cat("Run status:", agent$last_run()$stop_reason, "\n")
