test_that("projection separates elicited anchors and assumed behavior", {
  x <- suppose_example()
  j <- judgment(
    150,
    c(50, 60),
    c(0.05, 0.95),
    units = "MPa",
    author = "A",
    answer = "Midpoint expectation"
  )
  x <- record_judgment(x, j, "Inspect a new condition")
  z <- check_expectations(x, linear = TRUE)
  expect_identical(
    vapply(z$rows, function(r) r$condition_basis, character(1)),
    c(
      "assumed extrapolation",
      "elicited anchor",
      "assumed interpolation",
      "elicited anchor",
      "assumed extrapolation"
    )
  )
  p <- utils::tail(x$revisions, 1)[[1]]$candidate
  midpoint_sd <- sqrt(
    sum(p$mean_sd^2) / 4 + p$correlation * prod(p$mean_sd) / 2
  )
  expect_equal(
    z$expectations[[3]]$implied,
    mean(p$means) + qnorm(c(0.05, 0.95)) * midpoint_sd
  )
  expect_equal(z$rows[[3]]$mean_sd, midpoint_sd)
  expect_gt(z$rows[[3]]$outcome_sd, midpoint_sd)
  expect_equal(z$expectations[[1]]$difference, c(0, 0), tolerance = 1e-12)
  expect_snapshot(error = TRUE, check_expectations(x))
})

test_that("qualitative answers get consequences without invented confidence", {
  x <- suppose_example()
  j <- judgment(
    160,
    kind = "comparison",
    reference_condition = 140,
    units = "MPa",
    author = "A",
    answer = "Higher"
  )
  x <- record_judgment(x, j, "Compare")
  shape <- judgment(
    130,
    kind = "qualitative",
    quantity = "shape",
    reference_condition = 170,
    units = "MPa",
    author = "A",
    answer = "An interior peak"
  )
  x <- record_judgment(x, shape, "Expected shape")
  z <- check_expectations(x, linear = TRUE)
  p <- utils::tail(x$revisions, 1)[[1]]$candidate
  expected <- pnorm(
    diff(p$means) / sqrt(sum(p$mean_sd^2) - 2 * p$correlation * prod(p$mean_sd))
  )
  expect_equal(z$expectations[[3]]$implied, unname(expected))
  expect_null(z$expectations[[3]]$difference)
  expect_null(z$expectations[[3]]$judgment$probabilities)
  expect_match(
    z$expectations[[4]]$explanation,
    "cannot represent an interior peak"
  )
})
