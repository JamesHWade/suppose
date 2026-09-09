test_that("analytic and Monte Carlo predictions agree with reference calculations", {
  p <- suppose_example()$revisions[[2]]$candidate
  result <- predict_prior(p, n = 100000, seed = 42)
  expected_sd <- sqrt(sum((c(5, 7) / qnorm(.95))^2))
  expect_equal(
    result$summary$mean_difference$sd,
    expected_sd,
    tolerance = 1e-12
  )
  expect_equal(
    result$summary$mean_difference$probability_above,
    pnorm(3 / expected_sd),
    tolerance = 1e-12
  )
  expect_lt(abs(mean(result$draws$mean_difference) - 8), .06)
  expect_lt(abs(sd(result$draws$mean_difference) - expected_sd), .04)
  expect_equal(
    result$summary$batch_difference$sd^2,
    expected_sd^2 + 18,
    tolerance = 1e-10
  )
})
test_that("seeded predictions restore the caller's RNG state", {
  p <- suppose_example()$revisions[[2]]$candidate
  withr::local_seed(729)
  before <- .Random.seed
  a <- predict_prior(p, seed = 7)
  expect_identical(.Random.seed, before)
  expect_identical(a, predict_prior(p, seed = 7))
  expect_snapshot(error = TRUE, predict_prior(p, seed = NA_integer_))
})
test_that("perfect dependence allows a degenerate contrast", {
  ex <- suppose_example()$revisions[[2]]
  js <- ex$candidate$judgments
  js[[2]] <- judgment(
    160,
    c(45, 55),
    c(.05, .95),
    units = "MPa",
    author = "A",
    answer = "Same mean range"
  )
  p <- fit_prior(ex$claim, js, 1, c(0, 0))
  pred <- predict_prior(p)
  expect_equal(pred$summary$mean_difference$sd, 0)
  expect_equal(pred$summary$mean_difference$probability_above, 0)
  expect_equal(pred$draws$mean_difference, rep(0, pred$n))
})
