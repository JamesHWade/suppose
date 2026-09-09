test_that("reviewer corrections preserve the exact suggestion and clear numerical consequences", {
  x <- suppose_example()
  p <- compile_proposal(x, proposal_changes(), list(model = "fixture"))
  expect_s3_class(p$candidate, "suppose_prior")
  corrected <- apply_assistant_proposal(
    x,
    p,
    "Reviewer",
    corrections = list(
      wording = "Whether temperature affects response",
      expectations = NULL
    ),
    reason = "The original statement implied an established effect"
  )
  e <- tail(corrected$revisions, 1)[[1]]
  expect_identical(corrected$revisions[seq_along(x$revisions)], x$revisions)
  expect_identical(e$assistance$proposal, p)
  expect_identical(
    e$assistance$correction_reason,
    "The original statement implied an established effect"
  )
  expect_identical(e$claim$parent_id, tail(x$revisions, 1)[[1]]$claim$id)
  expect_identical(e$claim$wording, "Whether temperature affects response")
  expect_null(e$candidate)
  expect_null(e$prediction)
  expect_null(e$claim$threshold)
  expect_length(e$judgments, 0L)
  expect_null(e$acceptance)
  path <- withr::local_tempfile(fileext = ".json")
  write_record(corrected, path)
  expect_identical(json_data(read_record(path)), json_data(corrected))
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      corrected,
      p,
      "Reviewer",
      corrections = list(wording = "Another edit"),
      reason = "Again"
    )
  )
})

test_that("correction requires valid fields and a reason", {
  x <- elicitation_record(claim("An inquiry", "Reviewer"))
  p <- compile_proposal(x, proposal_changes(), list(), general = TRUE)
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(wording = "A change")
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(invented_field = "A change"),
      reason = "Clarify"
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(wording = ""),
      reason = "Clarify"
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = "A change",
      reason = "Clarify"
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(author = "Someone else"),
      reason = "Clarify"
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(wording = "First", wording = "Second"),
      reason = "Clarify"
    )
  )
  expect_snapshot(
    error = TRUE,
    apply_assistant_proposal(
      x,
      p,
      "Reviewer",
      corrections = list(threshold = 3),
      reason = "Clarify"
    )
  )
})

test_that("correction form distinguishes clearing a field from retaining it", {
  proposed <- claim(
    "Would this help?",
    "Reviewer",
    expectations = "Three teams say yes."
  )
  values <- lapply(names(inquiry_review_labels()), function(nm) {
    paste(proposed[[nm]] %||% "", collapse = "\n")
  })
  names(values) <- names(inquiry_review_labels())
  expect_length(inquiry_corrections(values, proposed), 0L)
  values$expectations <- ""
  values$unresolved <- " If three teams say yes, would that establish demand? \n\n"
  expect_identical(
    inquiry_corrections(values, proposed),
    list(
      expectations = NULL,
      unresolved = "If three teams say yes, would that establish demand?"
    )
  )
  values$wording <- NULL
  expect_snapshot(error = TRUE, inquiry_corrections(values, proposed))
})
