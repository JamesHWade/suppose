test_that("additional comparisons survive candidate retention and reopening", {
  x <- suppose_example()
  before <- x$revisions
  j <- judgment(
    160,
    kind = "comparison",
    quantity = "mean",
    units = "MPa",
    author = "Scientist",
    answer = "Higher than at 140, but I cannot give a probability",
    reference_condition = 140
  )
  y <- record_judgment(x, j, "Compare the two settings")
  e <- utils::tail(y$revisions, 1)[[1]]
  expect_identical(y$revisions[seq_along(before)], before)
  expect_identical(e$candidate, utils::tail(before, 1)[[1]]$candidate)
  expect_identical(utils::tail(e$judgments, 1)[[1]], j)
  expect_null(j$probabilities)
  expect_null(e$acceptance)
  path <- tempfile(fileext = ".json")
  write_record(y, path)
  expect_identical(json_data(read_record(path)), json_data(y))
  expect_snapshot(error = TRUE, record_judgment(y, j, "Repeat"))
})

test_that("shape regions and unknown comparisons retain their limitations", {
  j <- judgment(
    120,
    kind = "qualitative",
    quantity = "shape",
    units = "MPa",
    author = "A",
    answer = "Peaks somewhere in this region",
    reference_condition = 180
  )
  expect_identical(j$reference_condition, 180)
  expect_null(j$values)
  k <- judgment(
    160,
    kind = "comparison",
    units = "MPa",
    author = "A",
    answer = "Higher"
  )
  expect_match(k$issues[1], "reference condition")
})

test_that("manual expectation review rejects edits and duplicate clicks", {
  skip_if_no_app()
  x <- shiny::reactiveVal(suppose_example())
  shiny::testServer(
    judgment_server,
    args = list(current = x, guard = function() NULL),
    {
      session$setInputs(
        kind = "comparison",
        quantity = "mean",
        condition = 160,
        condition_units = "degC",
        reference = "140",
        units = "MPa",
        answer = "Higher",
        values = "",
        probabilities = "",
        rationale = "Experience",
        source = "",
        observed = ""
      )
      session$setInputs(preview = 1)
      expect_s3_class(preview()$judgment, "suppose_judgment")
      n <- length(x()$revisions)
      session$setInputs(answer = "About the same", retain = 1)
      expect_length(x()$revisions, n)
      expect_match(status(), "changed")
      session$setInputs(preview = 2)
      session$setInputs(retain = 2)
      expect_length(x()$revisions, n + 1L)
      expect_identical(
        utils::tail(x()$revisions, 1)[[1]]$judgments[[3]]$answer,
        "About the same"
      )
      session$setInputs(retain = 3)
      expect_length(x()$revisions, n + 1L)
    }
  )
})
