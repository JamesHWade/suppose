test_that("exact regression closes the omitted-predictor revision loop", {
  f <- regression_fixture()
  prior <- regression_test_prior(f)
  fit <- fit_regression(f$record, prior, TRUE, TRUE, draws = 300)
  expect_length(fit$fits, 2)
  expect_gt(fit$comparison$extended_minus_baseline, 50)
  expect_lt(fit$fits[[2]]$noise$median, fit$fits[[1]]$noise$median)
  baseline <- Filter(
    function(c) c$statistic == "residual_pattern_duration",
    fit$fits[[1]]$checks
  )[[1]]
  expect_identical(baseline$status, "review_mismatch")
  expect_gt(baseline$mc_interval[2], 0)
  expect_lt(baseline$mc_interval[2], 0.025)
  expect_equal(fit$fits[[2]]$coefficients[[3]]$mean, 18, tolerance = 0.3)
  x <- record_regression(
    f$record,
    fit,
    "extended",
    "Reviewer",
    "Duration explains a predictive mismatch; causal meaning remains unresolved",
    TRUE
  )
  expect_length(x$regressions, 1)
  expect_identical(x$revisions, f$record$revisions)
  expect_identical(x$observations, f$record$observations)
  path <- tempfile(fileext = ".json")
  write_record(x, path)
  reopened <- read_record(path)
  expect_identical(reopened$regressions[[1]]$id, x$regressions[[1]]$id)
  expect_identical(reopened$regressions[[1]]$result$id, fit$id)
  expect_equal(reopened$regressions[[1]]$result$comparison, fit$comparison)
})

test_that("every exact LOO score agrees with independent marginal likelihood ratios", {
  f <- regression_fixture(12)
  spec <- regression_test_prior(f)
  fit <- fit_regression(f$record, spec, TRUE, TRUE, draws = 200)
  marginal <- function(design, y, prior) {
    n <- length(y)
    covariance <- diag(n) + design %*% diag(prior$v_diagonal) %*% t(design)
    residual <- y - drop(design %*% prior$mean)
    rate <- prior$rate +
      drop(crossprod(residual, solve(covariance, residual))) / 2
    lgamma(prior$shape + n / 2) -
      lgamma(prior$shape) +
      prior$shape * log(prior$rate) -
      (prior$shape + n / 2) * log(rate) -
      n / 2 * log(2 * pi) -
      as.numeric(determinant(covariance, logarithm = TRUE)$modulus) / 2
  }
  for (k in 1:2) {
    design <- cbind(1, (f$data$temperature - 150) / 10)
    if (k == 2) {
      design <- cbind(design, (f$data$duration - 60) / 10)
    }
    prior <- spec$priors[[k]]
    full <- marginal(design, f$rows$outcome, prior)
    expected <- vapply(
      seq_len(nrow(design)),
      function(i) {
        full - marginal(design[-i, , drop = FALSE], f$rows$outcome[-i], prior)
      },
      numeric(1)
    )
    actual <- vapply(fit$fits[[k]]$loo, `[[`, numeric(1), "log_score")
    expect_equal(actual, expected, tolerance = 1e-10)
  }
  delta <- vapply(fit$fits[[2]]$loo, `[[`, numeric(1), "log_score") -
    vapply(fit$fits[[1]]$loo, `[[`, numeric(1), "log_score")
  expect_equal(fit$comparison$paired_se, sqrt(12 * stats::var(delta)))
})

test_that("predictive checks use joint draws and leave the caller RNG intact", {
  f <- regression_fixture(12)
  spec <- regression_test_prior(f, "temperature")
  set.seed(42)
  before <- .Random.seed
  a <- fit_regression(f$record, spec, TRUE, TRUE, draws = 4000, seed = 123)
  expect_identical(.Random.seed, before)
  b <- fit_regression(f$record, spec, TRUE, TRUE, draws = 4000, seed = 123)
  expect_equal(a$fits, b$fits)
  fit <- a$fits[[1]]
  v <- do.call(rbind, fit$posterior$v)
  xbar <- c(1, mean((f$data$temperature - 150) / 10))
  expected <- fit$posterior$rate /
    (fit$posterior$shape - 1) *
    (1 / 12 + drop(xbar %*% v %*% xbar))
  observed <- stats::var(fit$checks[[1]]$replicated)
  expect_lt(abs(observed / expected - 1), 0.12)
})

test_that("changing outcome values never changes default transforms or priors", {
  f <- regression_fixture()
  a <- regression_test_prior(f)
  f$rows$outcome <- f$rows$outcome + 1000
  x <- suppose_example()
  o <- import_observations(
    f$rows,
    "synthetic:shift",
    "Protocol",
    "Analyst",
    "MPa",
    "update",
    "explored"
  )
  x <- record_observations(x, o, "Changed synthetic outcomes")
  d <- regression_predictors(
    x,
    x$observations[[1]]$id,
    f$data,
    c(temperature = "degC", duration = "minutes"),
    "synthetic:covariates",
    "Analyst"
  )
  f2 <- list(record = record_predictors(x, d), design = d)
  b <- regression_test_prior(f2)
  expect_identical(a$transforms, b$transforms)
  expect_identical(a$priors, b$priors)
})

test_that("fitting and retention require review and reject stale results", {
  f <- regression_fixture()
  spec <- regression_test_prior(f)
  expect_snapshot(error = TRUE, fit_regression(f$record, spec))
  fit <- fit_regression(f$record, spec, TRUE, TRUE, draws = 200)
  expect_snapshot(
    error = TRUE,
    record_regression(f$record, fit, "extended", "You", "Reason")
  )
  x <- record_regression(
    f$record,
    fit,
    "neither",
    "You",
    "Both need further review",
    TRUE
  )
  expect_identical(x$regressions[[1]]$choice, "neither")
  expect_snapshot(
    error = TRUE,
    record_regression(x, fit, "extended", "You", "Reason", TRUE)
  )
  expect_snapshot(error = TRUE, fit_regression(x, spec, TRUE, TRUE))
})

test_that("new-case predictions preserve transforms, separate uncertainty and flag extrapolation", {
  f <- regression_fixture(12)
  r <- fit_regression(
    f$record,
    regression_test_prior(f),
    TRUE,
    TRUE,
    draws = 200
  )
  same <- predict_regression(r, f$data[c("temperature", "duration")])
  expected <- vapply(r$fits[[2]]$predictions, `[[`, numeric(1), "outcome_scale")
  expect_equal(vapply(same$rows, `[[`, numeric(1), "outcome_scale"), expected)
  pred <- predict_regression(
    r,
    data.frame(temperature = c(150, 180), duration = c(60, 80))
  )
  expect_identical(
    vapply(pred$rows, `[[`, logical(1), "outside_observed_range"),
    c(FALSE, TRUE)
  )
  expect_gt(pred$rows[[1]]$outcome_scale, pred$rows[[1]]$mean_scale)
  expect_equal(pred$rows[[1]]$mean, r$fits[[2]]$posterior$mean[1])
  expect_snapshot(
    error = TRUE,
    predict_regression(r, data.frame(temperature = 150))
  )
})

test_that("regression refuses assessment evidence, missing outcomes and repeated specimens", {
  assessment <- regression_fixture(12, role = "assessment", exposure = "unseen")
  expect_snapshot(error = TRUE, regression_test_prior(assessment))
  missing <- regression_fixture(12, missing = TRUE)
  expect_snapshot(error = TRUE, regression_test_prior(missing))
  repeated <- regression_fixture(12, repeated = TRUE)
  spec <- regression_test_prior(repeated)
  expect_snapshot(
    error = TRUE,
    fit_regression(repeated$record, spec, TRUE, TRUE)
  )
})

test_that("borderline predictive checks retain simulation uncertainty", {
  f <- regression_fixture()
  r <- fit_regression(f$record, regression_test_prior(f), TRUE, TRUE, seed = 1)
  check <- Filter(
    function(c) c$statistic == "largest_residual",
    r$fits[[2]]$checks
  )[[1]]
  expect_identical(check$status, "simulation_uncertain")
  expect_lt(check$mc_interval[1], 0.975)
  expect_gt(check$mc_interval[2], 0.975)
})
