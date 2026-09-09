# Deterministic scientific workflow probe. No external model is used.
pkgload::load_all(quiet = TRUE)
x <- elicitation_record(claim(
  "Hotter curing should make it stronger",
  "Demo scientist"
))
s <- suppose:::new_proposal_session(
  function() x,
  model = "scripted-fixture",
  provider = "local-test"
)
text <- "At 140 degC a plausible mean range is 45 to 55 MPa."
id <- s$begin(text)
tools <- s$tools(id)
tools[[3]](140, "mean", text, "Clarify range", 45, 55)
s$finish(id, "What probability does the range express?")
stopifnot(is.null(s$pending$candidate))
text <- paste(
  "For future batches under the same protocol compare mean strength at 160 and 140 degC in MPa, threshold 5 MPa.",
  "Central 90% intervals for the means: 140 degC 45 to 55 MPa; 160 degC 51 to 65 MPa.",
  "Assume correlation 0 and known batch SDs 3 and 3 MPa. Invented judgments; no observations used."
)
id <- s$begin(text)
tools <- s$tools(id)
tools[[2]](
  "Higher cure temperature increases mean batch strength",
  text,
  "Clarify target",
  scope = "Future batches under the same protocol",
  threshold = 5
)
tools[[3]](140, "mean", text, "Explicit central probability", 45, 55, .9)
tools[[3]](160, "mean", text, "Explicit central probability", 51, 65, .9)
tools[[4]](0, 3, 3, text, "Explicit supplied assumptions")
first <- tools[[5]]()
s$finish(id, "Inspect whether independence expresses your belief.")
text <- "Correct correlation to 0.8; batch SDs remain 3 and 3 MPa."
id <- s$begin(text)
tools <- s$tools(id)
tools[[4]](.8, 3, 3, text, "Shared uncertainty shifts both means")
corrected <- tools[[5]]()
s$finish(id, "Review the corrected assumptions and prior predictions.")
x <- apply_assistant_proposal(x, s$pending, "Demo scientist")
x <- accept_revision(
  x,
  "Demo scientist",
  "Synthetic workflow acceptance",
  "Randomized future batches under a prespecified protocol"
)
write_record(x, "artifacts/assistant-record.json", overwrite = TRUE)
stopifnot(identical(
  suppose:::json_data(x),
  suppose:::json_data(read_record("artifacts/assistant-record.json"))
))
cat("Scripted fixture; no live inference.\n")
cat(
  "P(mean improvement > 5 MPa), correlation 0:",
  first$summary$mean_difference$probability_above,
  "\n"
)
cat(
  "P(mean improvement > 5 MPa), correlation 0.8:",
  corrected$summary$mean_difference$probability_above,
  "\n"
)
cat(
  "Accepted schema-2 record saved and reopened with conversation and tool provenance.\n"
)
