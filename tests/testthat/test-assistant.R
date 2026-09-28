assistant_fixture <- function() {
  x <- elicitation_record(claim(
    "Hotter curing should make it stronger",
    "Scientist"
  ))
  s <- new_proposal_session(
    function() x,
    model = "fixture-model",
    provider = "fixture"
  )
  list(record = x, session = s)
}

test_that("elicitation clarification, correction and acceptance retain provenance", {
  skip_if_not_installed("ellmer")
  f <- assistant_fixture()
  s <- f$session
  text <- "At 140 degC a plausible mean range is 45 to 55 MPa."
  id <- s$begin(text)
  t <- s$tools(id)
  t[[3]](140, "mean", text, "Clarify interval", lower = 45, upper = 55)
  expect_null(jsonlite::fromJSON(t[[5]]())$summary)
  p <- s$finish(id, "What probability does this range express?")
  expect_identical(p$judgments[[1]]$kind, "range")
  expect_null(p$candidate)
  text <- paste(
    "For future batches under the same protocol, compare mean strength at 160 versus 140 degC in MPa; threshold 5 MPa.",
    "Central 90% intervals for means: 140 degC 45 to 55 MPa; 160 degC 51 to 65 MPa.",
    "Correlation 0, batch SDs 3 and 3 MPa."
  )
  id <- s$begin(text)
  t <- s$tools(id)
  t[[2]](
    "Higher curing temperature increases mean batch strength",
    text,
    "Specify target",
    scope = "Future batches under the same protocol",
    threshold = 5
  )
  t[[3]](140, "mean", text, "Explicit probability", 45, 55, .9)
  t[[3]](160, "mean", text, "Explicit probability", 51, 65, .9)
  t[[4]](0, 3, 3, text, "User assumptions")
  preview <- jsonlite::fromJSON(t[[5]]())
  p <- s$finish(id, "Review the independence assumption.")
  expect_true(p$candidate$fit_ok)
  expect_equal(preview$summary, p$prediction$summary)
  expect_identical(preview$prediction_id, p$prediction$id)
  text <- "Correct correlation to 0.8; batch SDs remain 3 and 3 MPa."
  id <- s$begin(text)
  t <- s$tools(id)
  t[[4]](.8, 3, 3, text, "Shared uncertain batch conditions")
  t[[5]]()
  p2 <- s$finish(id, "Review the corrected assumption and predictions.")
  expect_length(p2$judgments, 2)
  expect_equal(p2$candidate$correlation, .8)
  expect_false(identical(p2$prediction$summary, p$prediction$summary))
  out <- apply_assistant_proposal(f$record, p2, "Scientist")
  expect_null(tail(out$revisions, 1)[[1]]$acceptance)
  expect_error(
    apply_assistant_proposal(out, p2, "Scientist"),
    class = "suppose_stale"
  )
  out <- accept_revision(
    out,
    "Scientist",
    "Matches my belief",
    "Randomized future batches"
  )
  e <- tail(out$revisions, 1)[[1]]
  expect_identical(e$acceptance$assistance_id, e$assistance$id)
  expect_identical(e$assistance$proposal$context$model, "fixture-model")
  expect_length(e$assistance$proposal$context$messages, 6)
  path <- withr::local_tempfile(fileext = ".json")
  write_record(out, path)
  reopened <- read_record(path)
  expect_identical(json_data(reopened), json_data(out))
  expect_equal(reopened$schema_version, 2)
})

test_that("fabrications, stale requests and cancelled tools cannot produce proposals", {
  skip_if_not_installed("ellmer")
  x <- suppose_example(accept = TRUE)
  s <- new_proposal_session(function() x)
  id <- s$begin("At 140 degC I think the mean is 45 to 55 MPa.")
  t <- s$tools(id)
  expect_error(
    t[[3]](140, "mean", "Made up source", "Guess", 45, 55, .9),
    class = "suppose_source"
  )
  expect_error(
    t[[3]](140, "mean", s$messages[[1]]$text, "Guess probability", 45, 55, .9),
    class = "suppose_source"
  )
  expect_error(
    t[[3]](180, "mean", s$messages[[1]]$text, "Unsupported", 45, 55),
    class = "suppose_unsupported"
  )
  s$cancel()
  expect_error(t[[1]](), class = "suppose_cancelled")
  expect_error(s$finish(id, "Late result"), class = "suppose_cancelled")
  expect_null(s$pending)
  id <- s$begin("Retry")
  t <- s$tools(id)
  x <- record_revision(
    x,
    tail(x$revisions, 1)[[1]]$claim,
    reason = "Intervening edit"
  )
  expect_error(t[[1]](), class = "suppose_stale")
  expect_error(s$finish(id, "Late result"), class = "suppose_stale")
})

test_that("interrupted responses stay visible but are not replayed as turns", {
  skip_if_not_installed("ellmer")
  s <- assistant_fixture()$session
  for (reason in c("cancelled", "failed", "stopped")) {
    s$begin(paste("Question before a response was", reason))
    s$cancel(reason)
  }
  id <- s$begin("A question that gets an answer")
  s$finish(id, "A completed reply.")

  expect_length(s$messages, 8)
  expect_identical(
    vapply(s$messages[c(2, 4, 6)], `[[`, character(1), "status"),
    c("cancelled", "failed", "stopped")
  )
  turns <- inquiry_turns(s$messages)
  expect_identical(
    vapply(turns, ellmer::contents_text, character(1)),
    c(
      "Question before a response was cancelled",
      "Question before a response was failed",
      "Question before a response was stopped",
      "A question that gets an answer",
      "A completed reply."
    )
  )
  expect_identical(
    vapply(turns, function(turn) turn@role, character(1)),
    c("user", "user", "user", "user", "assistant")
  )
  expect_error(s$cancel("interrupted"), "must be one of")
})
