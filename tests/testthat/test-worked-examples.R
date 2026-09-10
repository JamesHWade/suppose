test_that("worked examples are complete, portable records with honest provenance", {
  withr::local_seed(91)
  before <- .Random.seed
  examples <- lapply(names(worked_examples()), suppose_worked_example)
  names(examples) <- names(worked_examples())
  for (x in examples) {
    validate_record(x)
    path <- tempfile(fileext = ".json")
    write_record(x, path)
    restored <- read_record(path)
    expect_identical(json_data(restored), json_data(x))
    expect_match(
      restored$conversation[[1]]$text,
      "Save conversation and record"
    )
  }
  expect_identical(.Random.seed, before)
  expect_length(examples$meetings$revisions, 2)
  expect_null(examples$meetings$revisions[[2]]$candidate)
  expect_identical(
    examples$meetings$revisions[[2]]$claim$original_wording,
    examples$meetings$revisions[[1]]$claim$wording
  )
  expect_length(examples$strength$revisions, 3)
  expect_gt(
    examples$strength$revisions[[
      3
    ]]$prediction$summary$mean_difference$probability_above,
    examples$strength$revisions[[
      2
    ]]$prediction$summary$mean_difference$probability_above
  )
  expect_length(examples$plants$updates, 1)
  expect_length(examples$plants$sensitivities, 1)
  expect_equal(examples$plants$revisions[[2]]$candidate$batch_sd, c(.6, .6))
  expect_match(examples$plants$conversation[[1]]$text, "Retrospective")
  expect_length(examples$regression$regressions, 2)
  expect_identical(
    vapply(examples$regression$regressions, `[[`, character(1), "choice"),
    c("neither", "extended")
  )
  expect_gt(
    examples$regression$regressions[[
      2
    ]]$result$comparison$extended_minus_baseline,
    0
  )
  expect_match(examples$regression$conversation[[1]]$text, "synthetic")
})

test_that("example navigation starts a separate unsaved copy and never mutates the supplied record", {
  original <- suppose_worked_example("meetings")
  before <- json_data(original)
  normal <- worked_example_session("", original, "my-history")
  expect_identical(normal$record, original)
  expect_identical(normal$history_dir, "my-history")
  unknown <- worked_example_session(
    "?suppose_example=unknown",
    original,
    "my-history"
  )
  expect_identical(unknown, normal)
  lesson <- worked_example_session(
    "?suppose_example=strength&shinychat_conversation_id=old",
    original,
    "my-history"
  )
  expect_null(lesson$history_dir)
  expect_length(lesson$record$revisions, 3)
  expect_identical(json_data(original), before)
  html <- as.character(worked_examples_ui())
  expect_equal(length(gregexpr('target="_blank"', html, fixed = TRUE)[[1]]), 5)
  expect_equal(length(gregexpr('rel="noopener"', html, fixed = TRUE)[[1]]), 5)
})

test_that("browsing the gallery preserves the active record and walkthrough", {
  x <- suppose_worked_example("meetings")
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(open_examples = 1)
      expect_identical(json_data(state$record()), json_data(x))
      expect_identical(state$transcript(), x$conversation)
      expect_match(output$save_notice, "Save before closing")
      saved <- read_record(output$save)
      expect_identical(saved$conversation, x$conversation)
    }
  )
})
