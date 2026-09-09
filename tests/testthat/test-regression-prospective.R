test_that("joint Student-t predictions have correct simultaneous and contrast coverage", {
  f <- regression_research_fixture("mean_difference")
  entry <- research_regression(f$before, f$design$regression_id)
  fit <- regression_selected_fit(entry)
  p <- fit$posterior
  design <- regression_model_matrix(
    list(predictors = as.list(f$data[c("temperature", "duration")])),
    entry$result$spec$transforms,
    fit$terms[-1]
  )
  withr::local_seed(72)
  n <- 20000
  sigma <- sqrt(1 / stats::rgamma(n, shape = p$shape, rate = p$rate))
  beta <- sweep(
    matrix(stats::rnorm(n * length(p$mean)), n) %*% chol(do.call(rbind, p$v)),
    1,
    sigma,
    "*"
  )
  beta <- sweep(beta, 2, p$mean, "+")
  outcomes <- beta %*%
    t(design) +
    matrix(stats::rnorm(n * nrow(design)), n) * sigma
  prediction <- f$plan$prediction
  differences <- sweep(outcomes, 2, prediction$location)
  q <- rowSums(
    (differences %*% solve(do.call(rbind, prediction$scale))) * differences
  )
  expect_equal(mean(q <= prediction$joint_cutoff), 0.9, tolerance = 0.01)
  contrasts <- drop(outcomes %*% prediction$contrast$weights)
  expect_equal(
    mean(
      contrasts >= prediction$contrast$lower &
        contrasts <= prediction$contrast$upper
    ),
    0.9,
    tolerance = 0.01
  )
  expect_gt(
    prediction$contrast$scale,
    prediction$contrast$population_mean_scale
  )
  expect_equal(
    stats::cov(outcomes),
    do.call(rbind, prediction$scale) * prediction$df / (prediction$df - 2),
    tolerance = 0.04
  )
})

test_that("partial cohorts, exact corrections and later revisions preserve frozen tests", {
  f <- regression_research_fixture()
  frozen <- f$record$regression_commitments[[1]]
  f$record <- regression_research_attach(f, f$data[1:2, ])
  f$record <- assess_regression_test(
    f$record,
    f$id,
    "Reviewer",
    "Await the complete cohort",
    TRUE
  )
  expect_identical(
    f$record$regression_assessments[[1]]$status,
    "awaiting_outcomes"
  )
  f$record <- regression_research_attach(f, f$data[3:4, ])
  f$record <- assess_regression_test(
    f$record,
    f$id,
    "Reviewer",
    "Complete cohort",
    TRUE
  )
  original_assessment <- f$record$regression_assessments[[2]]
  expect_identical(original_assessment$status, "within_prediction")
  correction <- f$data[3:4, ]
  correction$outcome[1] <- correction$outcome[1] + 100
  old_evidence <- f$record$regression_test_data[[2]]
  f$record <- regression_research_attach(f, correction, old_evidence$id)
  claim <- revise_claim(
    tail(f$record$revisions, 1)[[1]]$claim,
    "Reviewer",
    "Clarify scope after collection",
    scope = "Updated scope; original test remains fixed"
  )
  f$record <- record_revision(
    f$record,
    claim,
    reason = "Preserve historical prediction"
  )
  f$record <- assess_regression_test(
    f$record,
    f$id,
    "Reviewer",
    "Corrected measurement",
    TRUE
  )
  expect_identical(
    f$record$regression_assessments[[3]]$status,
    "outside_prediction"
  )
  expect_identical(f$record$regression_assessments[[2]], original_assessment)
  expect_identical(f$record$regression_test_data[[2]], old_evidence)
  expect_identical(f$record$regression_commitments[[1]], frozen)
  path <- tempfile(fileext = ".json")
  write_record(f$record, path)
  expect_identical(json_data(read_record(path)), json_data(f$record))
  expect_snapshot(
    error = TRUE,
    assess_regression_test(f$record, f$id, "Reviewer", "Duplicate", TRUE)
  )
})

test_that("missing data expire without a partial test and invalid collection stays inconclusive", {
  f <- regression_research_fixture("mean_difference")
  empty <- assess_regression_test(f$record, f$id, "Reviewer", "No outcomes yet")
  expect_identical(
    empty$regression_assessments[[1]]$status,
    "awaiting_outcomes"
  )
  f$clock$now <- "2026-01-04T12:00:00Z"
  expired <- assess_regression_test(
    empty,
    f$id,
    "Reviewer",
    "Deadline passed",
    TRUE
  )
  expect_identical(expired$regression_assessments[[2]]$status, "inconclusive")
  expect_null(expired$regression_assessments[[2]]$observed)
  for (kind in c("setting", "time", "unit")) {
    data <- f$data
    if (kind == "setting") {
      data$temperature[1] <- 150
    }
    if (kind == "time") {
      data$observed_at[1] <- "2025-12-31T12:00:00Z"
    }
    if (kind == "unit") {
      data$batch[2] <- data$batch[1]
      data$specimen[2] <- data$specimen[1]
    }
    out <- regression_research_attach(f, data)
    out <- assess_regression_test(
      out,
      f$id,
      "Reviewer",
      "Check eligibility",
      TRUE
    )
    expect_identical(out$regression_assessments[[1]]$status, "inconclusive")
  }
})

test_that("freezing rejects reused outcomes, stale previews and unreviewed declarations", {
  f <- regression_research_fixture()
  expect_snapshot(
    error = TRUE,
    commit_regression_test(f$before, f$plan, "Reviewer", "No confirmations")
  )
  expect_snapshot(
    error = TRUE,
    commit_regression_test(f$record, f$plan, "Reviewer", "Stale", TRUE, TRUE)
  )
  f$clock$now <- "2026-01-04T12:00:00Z"
  expect_snapshot(
    error = TRUE,
    commit_regression_test(f$before, f$plan, "Reviewer", "Expired", TRUE, TRUE)
  )
  f$clock$now <- "2026-01-01T12:00:00Z"
  data <- f$data[c("observation_id", "condition", "temperature", "duration")]
  data$observation_id[1] <- "r1"
  expect_snapshot(
    error = TRUE,
    plan_regression_test(
      f$before,
      f$design$regression_id,
      data,
      "synthetic:regression",
      "p",
      "2026-01-03T12:00:00Z",
      "target",
      design_details = "independent"
    )
  )
  f$record <- regression_research_attach(f)
  expect_snapshot(error = TRUE, regression_research_attach(f))
  expect_snapshot(
    error = TRUE,
    regression_research_attach(
      f,
      f$data[1:2, ],
      f$record$regression_test_data[[1]]$id
    )
  )
})

test_that("missing outcomes need explicit completion and mismatched declarations stay inconclusive", {
  f <- regression_research_fixture()
  missing <- f$data
  missing$outcome[4] <- NA_real_
  f$record <- regression_research_attach(f, missing)
  f$record <- assess_regression_test(
    f$record,
    f$id,
    "Reviewer",
    "Incomplete measurement",
    TRUE
  )
  expect_identical(f$record$regression_assessments[[1]]$missing_ids, "future-4")
  expect_null(f$record$regression_assessments[[1]]$observed)
  f$record <- regression_research_attach(
    f,
    f$data,
    f$record$regression_test_data[[1]]$id
  )
  f$record <- assess_regression_test(
    f$record,
    f$id,
    "Reviewer",
    "Completed correction",
    TRUE
  )
  expect_identical(
    f$record$regression_assessments[[2]]$status,
    "within_prediction"
  )
  expect_equal(
    f$record$regression_test_data[[1]]$data$rows[[4]]$converted,
    NULL
  )
  for (field in c("source", "protocol", "units", "predictor_units")) {
    g <- regression_research_fixture()
    args <- list(
      x = g$record,
      commitment_id = g$id,
      data = g$data,
      source = "future:regression",
      protocol = "randomized-v1",
      units = "MPa",
      predictor_units = c(temperature = "degC", duration = "minutes"),
      author = "Collector",
      reason = "Check declarations",
      outcomes_unseen = TRUE
    )
    args[[field]] <- if (field == "predictor_units") {
      c(temperature = "kelvin", duration = "minutes")
    } else {
      "mismatched"
    }
    out <- do.call(record_regression_test_data, args)
    out <- assess_regression_test(
      out,
      g$id,
      "Reviewer",
      "Check eligibility",
      TRUE
    )
    expect_identical(out$regression_assessments[[1]]$status, "inconclusive")
  }
})

test_that("a linked commitment must match an accepted planning choice", {
  f <- regression_research_fixture()
  d <- research_design_test_preview(f$design)
  x <- record_research_design(
    f$before,
    d,
    "none",
    "Reviewer",
    "Decline options",
    TRUE
  )
  args <- list(
    x = x,
    regression_id = f$design$regression_id,
    planned = f$data[c(
      "observation_id",
      "condition",
      "temperature",
      "duration"
    )],
    source = "future:linked",
    protocol = "independent-v1",
    horizon = "2026-01-03T12:00:00Z",
    target = "Challenge prediction",
    design_details = "Independent units",
    plan_id = x$research_designs[[1]]$id
  )
  expect_snapshot(error = TRUE, do.call(plan_regression_test, args))
  x <- record_research_design(
    f$before,
    d,
    "replicated",
    "Reviewer",
    "Review replication",
    TRUE
  )
  args$x <- x
  args$plan_id <- x$research_designs[[1]]$id
  expect_snapshot(error = TRUE, do.call(plan_regression_test, args))
  args$planned <- data.frame(
    observation_id = paste0("planned-", 1:6),
    condition = "planned",
    temperature = 160,
    duration = 60
  )
  preview <- do.call(plan_regression_test, args)
  x <- commit_regression_test(
    x,
    preview,
    "Reviewer",
    "Freeze accepted setting",
    TRUE,
    TRUE
  )
  expect_identical(x$regression_commitments[[1]]$plan_id, args$plan_id)
})
