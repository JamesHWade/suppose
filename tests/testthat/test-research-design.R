test_that("BED links exact scores to retained models without changing scientific evidence", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  d <- research_design_test_preview(f)
  expect_s3_class(d, "suppose_research_design")
  expect_identical(d$recommended, "replicated")
  expect_equal(d$candidates[[5]]$eligible, FALSE)
  expect_equal(d$candidates[[5]]$outside_observed_range, TRUE)
  expect_gt(d$candidates[[4]]$benefit, d$candidates[[3]]$benefit)
  expect_identical(
    d$model_checks,
    lapply(f$record$regressions[[1]]$result$fits[[2]]$checks, function(c) {
      c[setdiff(names(c), "replicated")]
    })
  )
  x <- record_research_design(
    f$record,
    d,
    "replicated",
    "Reviewer",
    "Learn the fixed-time contrast; energy remains unresolved",
    TRUE
  )
  expect_identical(x$regressions, f$record$regressions)
  expect_identical(x$observations, f$record$observations)
  expect_length(x$commitments, 0)
  expect_length(x$research_designs, 1)
  path <- tempfile(fileext = ".json")
  write_record(x, path)
  expect_identical(json_data(read_record(path)), json_data(x))
  expect_s3_class(
    read_record(path)$research_designs[[1]]$design,
    "suppose_research_design"
  )
})

test_that("costs, feasibility and budgets allow no experiment", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  d <- research_design_test_preview(f, max_units = 1)
  expect_equal(d$candidates[[4]]$eligible, FALSE)
  f$candidates$cost <- 1e6
  d <- research_design_test_preview(f)
  expect_length(d$recommended, 0)
  expect_match(d$no_design_reason, "positive net")
  x <- record_research_design(
    f$record,
    d,
    "none",
    "Reviewer",
    "No experiment justifies its assumed cost",
    TRUE
  )
  path <- tempfile(fileext = ".json")
  write_record(x, path)
  expect_identical(json_data(read_record(path)), json_data(x))
})

test_that("decision preferences change value without being mistaken for data", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  estimate <- research_design_test_preview(f)
  decide <- research_design_test_preview(
    f,
    purpose = "decide",
    threshold = estimate$current$contrast_mean,
    preference = "Synthetic utility: indifferent at this stated outcome-equivalent penalty, no claim about energy"
  )
  far <- research_design_test_preview(
    f,
    purpose = "decide",
    threshold = 1000,
    preference = "Synthetic expensive second protocol"
  )
  expect_gt(decide$current_loss, far$current_loss)
  expect_gt(decide$candidates[[4]]$benefit, far$candidates[[4]]$benefit)
  expect_match(decide$loss_units, "equivalent utility")
  expect_match(estimate$loss_units, "squared")
  expect_identical(decide$fit_id, estimate$fit_id)
})

test_that("reviews reject stale, missing, ineligible and malformed inputs", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  d <- research_design_test_preview(f)
  expect_snapshot(
    error = TRUE,
    research_design_test_preview(f, purpose = "decide")
  )
  expect_snapshot(
    error = TRUE,
    record_research_design(f$record, d, "low", "Reviewer", "Reason")
  )
  expect_snapshot(
    error = TRUE,
    record_research_design(
      f$record,
      d,
      "unavailable",
      "Reviewer",
      "Reason",
      TRUE
    )
  )
  retained <- record_research_design(
    f$record,
    d,
    "none",
    "Reviewer",
    "Pause",
    TRUE
  )
  expect_snapshot(
    error = TRUE,
    record_research_design(retained, d, "low", "Reviewer", "Reason", TRUE)
  )
  f$candidates$repeats[1] <- 1.5
  expect_snapshot(error = TRUE, research_design_test_preview(f))
  f$candidates$repeats[1] <- 1
  f$candidates$temperature[1] <- NA_real_
  expect_snapshot(error = TRUE, research_design_test_preview(f))
})
