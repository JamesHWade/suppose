test_that("analytic updating matches independent precision calculations", {
  f <- update_fixture()
  fit <- update_prior(f$prior, f$obs, f$map, independent = TRUE)
  sigma <- outer(f$prior$mean_sd, f$prior$mean_sd) *
    matrix(c(1, 0.8, 0.8, 1), 2)
  variance <- solve(solve(sigma) + diag(3 / f$prior$batch_sd^2))
  mean <- variance %*%
    (solve(sigma, f$prior$means) + c(50, 60) * 3 / f$prior$batch_sd^2)
  expect_equal(fit$posterior$means, as.numeric(mean), tolerance = 1e-10)
  expect_equal(matrix(fit$posterior$covariance, 2), variance, tolerance = 1e-10)
  expect_lt(fit$target$sd, fit$prior$sd)
  expect_gt(fit$predictive$sd, fit$target$sd)
  expect_identical(fit$diagnostics$computation, "completed")
})

test_that("singular priors and incomplete groups remain well-defined", {
  f <- update_fixture(c(49, 51, NA_real_), rep("low", 3))
  p <- fit_prior(
    f$prior$claim,
    f$prior$judgments,
    correlation = 1,
    batch_sd = c(3, 3)
  )
  fit <- update_prior(p, f$obs, f$map, independent = TRUE)
  expect_length(fit$excluded, 1)
  expect_identical(fit$groups[[2]]$n, 0L)
  expect_identical(
    fit$diagnostics$measurement_variation[[2]]$status,
    "insufficient_data"
  )
  expect_equal(det(matrix(fit$posterior$covariance, 2)), 0, tolerance = 1e-10)
  expect_lt(abs(fit$posterior$means[1] - 50), abs(p$means[1] - 50) + 1e-10)
})

test_that("known-variance mismatch and prior conflict are separate from computation", {
  f <- update_fixture(rep(c(-100, 100), 10), rep(c("low", "high"), each = 10))
  fit <- update_prior(f$prior, f$obs, f$map, independent = TRUE)
  expect_identical(fit$diagnostics$computation, "completed")
  expect_identical(
    fit$diagnostics$measurement_variation[[1]]$status,
    "model_mismatch"
  )
  expect_identical(
    fit$diagnostics$prior_predictive_conflict$status,
    "prior_data_conflict"
  )
})

test_that("updating requires explicit evidence roles and independence", {
  f <- update_fixture()
  expect_snapshot(error = TRUE, update_prior(f$prior, f$obs, f$map))
  expect_snapshot(
    error = TRUE,
    update_prior(f$prior, f$obs, c(other = 140, high = 160), independent = TRUE)
  )
  expect_snapshot(
    error = TRUE,
    update_prior(f$prior, list(f$obs, f$obs), f$map, independent = TRUE)
  )
  explored <- f$obs
  explored$id <- explored$type <- NULL
  explored$role <- "exploration"
  explored <- seal(explored, "suppose_observations")
  expect_snapshot(
    error = TRUE,
    update_prior(f$prior, explored, f$map, independent = TRUE)
  )
})

test_that("retained updates preserve the original record and survive JSON", {
  f <- update_fixture()
  record <- f$record
  original <- record$revisions
  record <- record_observations(
    record,
    f$obs,
    "Update this prior with measurements"
  )
  fit <- update_prior(f$prior, f$obs, f$map, independent = TRUE)
  updated <- record_update(
    record,
    fit,
    "Inspect consequences of new measurements"
  )
  expect_identical(updated$revisions, original)
  expect_equal(updated$updates[[1]]$result$target, fit$target)
  expect_equal(updated$schema_version, 5L)
  path <- tempfile(fileext = ".json")
  write_record(updated, path)
  restored <- read_record(path)
  expect_identical(json_data(restored), json_data(updated))
  expect_snapshot(error = TRUE, record_update(record, fit, ""))
})
