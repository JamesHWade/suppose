# Opt-in synthetic conversation. Requires OPENROUTER_API_KEY configured locally.
# Prompts are sent to Meta's Contributor model through OpenRouter.
pkgload::load_all(quiet = TRUE)
if (!nzchar(Sys.getenv("OPENROUTER_API_KEY"))) {
  stop("Configure OPENROUTER_API_KEY locally before this opt-in live check.")
}
x <- elicitation_record(claim(
  "Hotter curing should make it stronger",
  "Demo scientist"
))
s <- suppose:::new_proposal_session(
  function() x,
  model = "meta/muse-spark-1.3-contributor",
  provider = "OpenRouter"
)
client <- suppose_muse()
client$set_system_prompt(suppose:::assistant_prompt())
messages <- c(
  "Hotter curing should make it stronger. Help me make that precise; ask me what you need.",
  paste(
    "I mean future batch means under our current protocol: mean strength at 160 degC minus mean strength at 140 degC, in MPa. A material gain is 5 MPa.",
    "At 140 degC, 45 to 55 MPa seems plausible; at 160 degC, 51 to 65 MPa seems plausible. These are invented judgments, not observed data."
  ),
  paste(
    "Those are central 90% probability intervals for the population means:",
    "140 degC 45 to 55 MPa, 160 degC 51 to 65 MPa. Assume correlation 0 and known batch SDs 3 and 3 MPa.",
    "Please propose the claim, judgments and assumptions, and preview the consequences."
  ),
  "Correct the correlation to 0.8; batch SDs remain 3 and 3 MPa. Keep the marginal judgments. Please preview the corrected proposal."
)
for (message in messages) {
  id <- s$begin(message)
  client$set_tools(s$tools(id))
  response <- client$chat(message)
  s$finish(id, response)
  cat("\nUSER:", message, "\nASSISTANT:", response, "\n")
}
p <- s$pending
stopifnot(
  !is.null(p$candidate),
  p$candidate$fit_ok,
  p$candidate$correlation == .8
)
# The harness explicitly applies and accepts only the synthetic demo judgments.
x <- apply_assistant_proposal(x, p, "Demo scientist")
x <- accept_revision(
  x,
  "Demo scientist",
  "Synthetic acceptance test",
  "Randomized future batches"
)
path <- tempfile("suppose-live-", fileext = ".json")
write_record(x, path)
stopifnot(identical(
  suppose:::json_data(x),
  suppose:::json_data(read_record(path))
))
cat("\nLive transcript and accepted synthetic record:", path, "\n")
