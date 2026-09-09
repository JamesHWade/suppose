test_that("ambiguous and qualitative answers stay unresolved", {
  x <- judgment(
    140,
    c(45, 55),
    kind = "range",
    units = "MPa",
    author = "A",
    answer = "Plausible range"
  )
  expect_null(x$probabilities)
  expect_length(x$issues, 1)
  y <- judgment(
    140,
    kind = "qualitative",
    quantity = "shape",
    units = "MPa",
    author = "B",
    answer = "A plateau"
  )
  expect_null(y$values)
  expect_identical(y$answer, "A plateau")
  z <- judgment(
    140,
    c(55, 45),
    c(.05, .95),
    units = "MPa",
    author = "A",
    answer = "My answer"
  )
  expect_identical(z$values, c(55, 45))
  expect_length(z$issues, 1)
})
test_that("invalid probabilities have actionable errors", {
  expect_snapshot(
    error = TRUE,
    judgment(
      140,
      c(45, 55),
      c(0, 1),
      units = "MPa",
      author = "A",
      answer = "Answer"
    )
  )
})
