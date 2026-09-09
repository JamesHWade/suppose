test_that("incomplete and revised claims preserve their meaning and attribution", {
  x <- claim("Temperature helps", "A")
  y <- revise_claim(
    x,
    "B",
    "Define the population",
    scope = "Formulation F",
    units = "MPa",
    assumptions = character()
  )
  expect_null(x$scope)
  expect_null(x$assumptions)
  expect_identical(y$assumptions, character())
  expect_identical(y$parent_id, x$id)
  expect_identical(y$original_wording, x$wording)
  expect_identical(y$author, "B")
  expect_null(y$threshold)
  expect_snapshot(
    error = TRUE,
    revise_claim(x, "B", "Correction", confidence = .9)
  )
})
test_that("changed fields invalidate content identifiers", {
  x <- claim("Temperature helps", "A")
  x$wording <- "Something else"
  expect_snapshot(error = TRUE, revise_claim(x, "B", "Correction"))
})
