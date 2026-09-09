test_that("normal quantile fitting recovers independently specified parameters", {
  c <- claim(
    "Higher strength",
    "A",
    target = "Mean contrast",
    units = "MPa",
    scope = "F/P",
    threshold = 5
  )
  probs <- c(.05, .5, .95)
  js <- list(
    judgment(
      140,
      qnorm(probs, 50, 3),
      probs,
      units = "MPa",
      author = "A",
      answer = "Synthetic"
    ),
    judgment(
      160,
      qnorm(probs, 58, 4),
      probs,
      units = "MPa",
      author = "A",
      answer = "Synthetic"
    )
  )
  p <- fit_prior(c, js, correlation = 0, batch_sd = c(2, 3))
  expect_equal(p$means, c(50, 58), tolerance = 1e-12)
  expect_equal(p$mean_sd, c(3, 4), tolerance = 1e-12)
  expect_lt(p$max_error, 1e-12)
  p2 <- fit_prior(c, js, correlation = .8, batch_sd = c(2, 3))
  expect_identical(p$fits, p2$fits)
  expect_gt(
    predict_prior(p)$summary$mean_difference$sd,
    predict_prior(p2)$summary$mean_difference$sd
  )
})
test_that("incompatible summaries return measurable mismatch", {
  ex <- suppose_example()$revisions[[2]]
  js <- ex$candidate$judgments
  js[[1]] <- judgment(
    140,
    c(45, 46, 55),
    c(.05, .5, .95),
    units = "MPa",
    author = "A",
    answer = "Asymmetric"
  )
  p <- fit_prior(ex$claim, js, correlation = 0, batch_sd = c(3, 3))
  expect_identical(p$fit_ok, FALSE)
  expect_gt(p$max_error, 2)
  rec <- elicitation_record(ex$claim) |>
    record_revision(ex$claim, p, predict_prior(p), reason = "Test")
  expect_snapshot(
    error = TRUE,
    accept_revision(rec, "A", "Reviewed", "New data")
  )
})
test_that("units and unresolved judgments cannot be silently fitted", {
  ex <- suppose_example()$revisions[[2]]
  js <- ex$candidate$judgments
  js[[1]] <- judgment(
    140,
    c(45, 55),
    c(.05, .95),
    units = "kPa",
    author = "A",
    answer = "Wrong units"
  )
  err <- tryCatch(fit_prior(ex$claim, js, 0, c(3, 3)), error = identity)
  expect_s3_class(err, "suppose_units")
  js[[1]] <- judgment(
    140,
    c(55, 45),
    c(.05, .95),
    units = "MPa",
    author = "A",
    answer = "Contradictory"
  )
  expect_snapshot(error = TRUE, fit_prior(ex$claim, js, 0, c(3, 3)))
})
