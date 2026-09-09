test_that("power scaling agrees with independent precision calculations", {
  f <- sensitivity_fixture()
  s <- sensitivity_analysis(f$record, f$update$id)
  sigma <- outer(f$prior$mean_sd, f$prior$mean_sd) *
    matrix(c(1, 0.8, 0.8, 1), 2)
  for (row in s$rows) {
    ap <- if (row$component == "prior") row$power else 1
    al <- if (row$component == "likelihood") row$power else 1
    covariance <- solve(ap * solve(sigma) + al * diag(3 / f$prior$batch_sd^2))
    means <- covariance %*%
      (ap *
        solve(sigma, f$prior$means) +
        al * c(0, 100) * 3 / f$prior$batch_sd^2)
    sd <- sqrt(drop(c(-1, 1) %*% covariance %*% c(-1, 1)))
    expect_identical(row$status, "completed")
    expect_equal(row$target$mean, diff(as.numeric(means)), tolerance = 1e-10)
    expect_equal(row$target$sd, sd, tolerance = 1e-10)
    expect_equal(
      row$target$probability_above,
      pnorm(5, diff(as.numeric(means)), sd, lower.tail = FALSE),
      tolerance = 1e-10
    )
    if (row$power == 1) {
      expect_equal(row$target, f$update$result$target)
      expect_equal(row$estimate_change, 0)
    }
  }
  expect_identical(s$settings$method, "analytic-normal-power-scaling-v1")
  expect_identical(s$evidence_ids, f$update$evidence_ids)
})

test_that("sensitive and insensitive cases use explicitly selected review thresholds", {
  f <- sensitivity_fixture()
  s <- sensitivity_analysis(
    f$record,
    f$update$id,
    quantities = "estimate",
    estimate_change = 1
  )
  expect_gt(max(abs(vapply(s$rows, `[[`, numeric(1), "estimate_change"))), 1)
  expect_match(paste(s$followup, collapse = " "), "elicited interval")
  expect_match(paste(s$followup, collapse = " "), "independence")
  stable <- sensitivity_fixture(
    rep(c(50, 58), each = 100),
    rep(c("low", "high"), each = 100)
  )
  out <- sensitivity_analysis(stable$record, stable$update$id)
  expect_lt(
    max(abs(vapply(out$rows, `[[`, numeric(1), "estimate_change"))),
    1e-10
  )
  expect_lt(
    max(abs(vapply(out$rows, `[[`, numeric(1), "probability_change"))),
    0.05
  )
  expect_match(out$followup, "not a robustness certificate")
  selected <- sensitivity_analysis(
    f$record,
    f$update$id,
    components = "prior",
    quantities = "probability"
  )
  expect_length(selected$rows, 3)
  expect_identical(
    vapply(selected$rows, `[[`, logical(1), "review_estimate"),
    rep(FALSE, 3)
  )
})

test_that("assessment comparisons are exploratory and keep the exact frozen baseline", {
  f <- prospective_fixture(updated = TRUE)
  # A point on the original inclusive interval can change under a weaker prior.
  difference <- f$c$prediction$upper
  x <- record_observations(
    f$record,
    prospective_observations(f, c(0, 0, difference, difference)),
    "Synthetic boundary outcomes"
  )
  x <- assess_test(x, f$c$id, "Reviewer", "Original assessment", TRUE)
  s <- sensitivity_analysis(x, x$updates[[1]]$id)
  for (row in s$rows) {
    a <- row$assessments[[1]]
    expect_identical(a$original_status, "within_prediction")
    expect_equal(a$observed, difference)
    if (row$power == 1) {
      expect_identical(a$status, "within_prediction")
      expect_equal(
        c(a$lower, a$upper),
        c(f$c$prediction$lower, f$c$prediction$upper)
      )
    } else {
      expected_sd <- sqrt(row$target$sd^2 + 9)
      expect_equal(a$upper, row$target$mean + qnorm(0.95) * expected_sd)
    }
  }
  expect_gt(sum(vapply(s$rows, `[[`, logical(1), "review_assessment")), 0)
  retained <- record_sensitivity(x, s, "Review the boundary")
  expect_identical(retained$assessments, x$assessments)
  expect_identical(retained$commitments, x$commitments)
  expect_identical(retained$updates, x$updates)
  expect_identical(retained$revisions, x$revisions)
})

test_that("waiting assessments stay nonnumeric and different bases are explicit", {
  f <- prospective_fixture(updated = TRUE)
  x <- assess_test(f$record, f$c$id, "Reviewer", "No data", TRUE)
  s <- sensitivity_analysis(x, x$updates[[1]]$id)
  expect_identical(s$rows[[1]]$assessments[[1]]$status, "no_numeric_assessment")
  expect_null(s$rows[[1]]$assessments[[1]]$observed)
  other <- commit_test(
    x,
    f$plan,
    c(low = 140, high = 160),
    "different",
    "different",
    "2026-01-03T12:00:00Z",
    "Reviewer",
    "A different prior basis",
    design_details = "Independent units",
    independent = TRUE,
    outcomes_unseen = TRUE
  )
  other <- assess_test(
    other,
    other$commitments[[2]]$id,
    "Reviewer",
    "No data",
    TRUE
  )
  s <- sensitivity_analysis(other, other$updates[[1]]$id)
  expect_identical(s$rows[[1]]$assessments[[2]]$status, "not_comparable")
  expect_match(s$rows[[1]]$assessments[[2]]$reason, "different")
})

test_that("failed or numerically invalid perturbations remain visible", {
  f <- sensitivity_fixture()
  original <- update_normal
  local_mocked_bindings(update_normal = function(
    ...,
    prior_power = 1,
    likelihood_power = 1
  ) {
    if (prior_power < 1) {
      abort_suppose("Synthetic numerical failure", "computation")
    }
    fit <- original(
      ...,
      prior_power = prior_power,
      likelihood_power = likelihood_power
    )
    if (prior_power > 1) {
      fit$posterior$covariance <- c(-1, 0, 0, -1)
    }
    fit
  })
  s <- sensitivity_analysis(f$record, f$update$id, components = "prior")
  expect_identical(
    vapply(s$rows, `[[`, character(1), "status"),
    c("failed", "completed", "failed")
  )
  expect_null(s$rows[[1]]$target)
  expect_match(s$rows[[1]]$error, "Synthetic numerical failure")
  expect_match(s$rows[[3]]$error, "numerically invalid")
  expect_match(s$followup, "Some perturbations failed")
  path <- tempfile(fileext = ".json")
  retained <- record_sensitivity(f$record, s, "Review failures")
  write_record(retained, path)
  expect_identical(json_data(read_record(path)), json_data(retained))
})

test_that("singular normal priors preserve their support under power scaling", {
  f <- update_fixture()
  p <- fit_prior(f$prior$claim, f$prior$judgments, 1, c(3, 3))
  x <- record_revision(
    f$record,
    p$claim,
    candidate = p,
    reason = "Singular prior"
  )
  x <- record_observations(x, f$obs, "Training")
  x <- record_update(x, update_prior(p, f$obs, f$map, TRUE), "Singular update")
  s <- sensitivity_analysis(x, x$updates[[1]]$id, powers = c(0.1, 10))
  expect_identical(
    vapply(s$rows, `[[`, character(1), "status"),
    rep("completed", 6)
  )
  expect_equal(s$baseline, x$updates[[1]]$result$target)
})

test_that("retention round trips exact references and rejects stale or changed records", {
  f <- sensitivity_fixture()
  s <- sensitivity_analysis(f$record, f$update$id)
  x <- record_sensitivity(f$record, s, "Review the model")
  path <- tempfile(fileext = ".json")
  write_record(x, path)
  reopened <- read_record(path)
  expect_identical(json_data(reopened), json_data(x))
  expect_s3_class(reopened$sensitivities[[1]]$result, "suppose_sensitivity")
  expect_identical(cli_record_summary(x)$sensitivities, plain(x$sensitivities))
  expect_snapshot(error = TRUE, record_sensitivity(x, s, "Stale"))
  tampered <- x
  tampered$sensitivities[[1]]$result$rows[[1]]$power <- 2
  expect_snapshot(error = TRUE, validate_record(tampered))
  tampered <- x
  bad <- tampered$sensitivities[[1]]$result
  bad$update_id <- "missing"
  bad$id <- bad$type <- NULL
  entry <- tampered$sensitivities[[1]]
  entry$result <- seal(bad, "suppose_sensitivity")
  entry$id <- entry$type <- NULL
  tampered$sensitivities[[1]] <- seal(entry, "suppose_sensitivity_entry")
  expect_snapshot(error = TRUE, validate_record(tampered))
})

test_that("unsupported perturbations and output choices fail explicitly", {
  f <- sensitivity_fixture()
  expect_snapshot(error = TRUE, sensitivity_analysis(f$record, "missing"))
  expect_snapshot(
    error = TRUE,
    sensitivity_analysis(f$record, f$update$id, powers = c(0, 1))
  )
  expect_snapshot(
    error = TRUE,
    sensitivity_analysis(f$record, f$update$id, components = "shape")
  )
  expect_snapshot(
    error = TRUE,
    sensitivity_analysis(f$record, f$update$id, quantities = "causal_effect")
  )
  expect_snapshot(
    error = TRUE,
    sensitivity_analysis(f$record, f$update$id, probability_change = 0)
  )
})
