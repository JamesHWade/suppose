test_that("aligned extension predictions agree with a joint normal reference", {
  x <- suppose_example()
  p <- x$revisions[[3]]$candidate
  c <- compare_extension(
    x,
    "Duration",
    "minutes",
    60,
    10,
    effect_mean = 2,
    effect_sd = 3,
    plausible_lower = 0,
    plausible_upper = 100
  )
  sigma <- outer(p$mean_sd, p$mean_sd) *
    matrix(c(1, p$correlation, p$correlation, 1), 2)
  joint <- matrix(0, 3, 3)
  joint[1:2, 1:2] <- sigma
  joint[3, 3] <- 9
  for (row in c$rows) {
    t <- (row$condition - 140) / 20
    z <- switch(
      row$model,
      original = 0,
      unscaled = row$predictor_value - 60,
      scaled = (row$predictor_value - 60) / 10
    )
    weights <- c(1 - t, t, z)
    mean <- sum(weights * c(p$means, 2))
    sd <- sqrt(drop(weights %*% joint %*% weights))
    expect_equal(row$mean, mean)
    expect_equal(row$mean_sd, sd)
    expect_equal(row$outcome_sd, sqrt(sd^2 + 9))
    expect_equal(row$outcome_upper, mean + qnorm(0.95) * sqrt(sd^2 + 9))
    expect_equal(
      row$outside_probability,
      pnorm(0, mean, sqrt(sd^2 + 9)) +
        pnorm(100, mean, sqrt(sd^2 + 9), lower.tail = FALSE)
    )
  }
  expect_equal(c$matched_contrast$mean, 8)
  expect_match(c$matched_contrast$explanation, "cancels")
  expect_setequal(
    unique(vapply(c$rows, `[[`, character(1), "condition_basis")),
    c("elicited anchor", "assumed interpolation", "assumed extrapolation")
  )
})

test_that("meaningful scaling is invariant to predictor units and reveals naive inflation", {
  x <- suppose_example()
  minutes <- compare_extension(x, "Duration", "minutes", 60, 10)
  seconds <- compare_extension(x, "Duration", "seconds", 3600, 600)
  scaled <- function(c) Filter(function(r) r$model == "scaled", c$rows)
  a <- scaled(minutes)
  b <- scaled(seconds)
  expect_equal(
    vapply(a, `[[`, numeric(1), "outcome_sd"),
    vapply(b, `[[`, numeric(1), "outcome_sd")
  )
  edge <- Filter(
    function(r) r$condition == 140 && r$predictor_value == 50,
    minutes$rows
  )
  expect_gt(edge[[2]]$outcome_sd, 5 * edge[[3]]$outcome_sd)
  middle <- Filter(
    function(r) r$condition == 140 && r$predictor_value == 60,
    minutes$rows
  )
  expect_equal(middle[[1]]$outcome_sd, middle[[2]]$outcome_sd)
  expect_equal(middle[[1]]$outcome_sd, middle[[3]]$outcome_sd)
  expect_match(minutes$defaults$effect_sd, "Starting suggestion")
})

test_that("reviewed alternatives preserve original records and round trip", {
  f <- prospective_fixture(updated = TRUE)
  c <- compare_extension(f$record, "Duration", "minutes", 60, 10)
  x <- record_extension(
    f$record,
    c,
    "Reviewer",
    "Duration may alter strength",
    reviewed = TRUE
  )
  expect_identical(x$revisions, f$record$revisions)
  expect_identical(x$commitments, f$record$commitments)
  expect_identical(x$updates, f$record$updates)
  expect_identical(x$model_extensions[[1]]$choice, "scaled")
  path <- tempfile(fileext = ".json")
  write_record(x, path)
  restored <- read_record(path)
  expect_identical(json_data(restored), json_data(x))
  expect_s3_class(
    restored$model_extensions[[1]]$comparison,
    "suppose_extension_comparison"
  )
  expect_snapshot(
    error = TRUE,
    record_extension(x, c, "Reviewer", "Stale", reviewed = TRUE)
  )
  expect_snapshot(
    error = TRUE,
    record_extension(f$record, c, "Reviewer", "Not yet reviewed")
  )
})

test_that("unsupported and failed extension calculations do not create a model", {
  x <- suppose_example()
  expect_snapshot(error = TRUE, compare_extension(x, "Duration", scale = 0))
  expect_snapshot(
    error = TRUE,
    compare_extension(x, "Duration", effect_sd = -1)
  )
  expect_snapshot(
    error = TRUE,
    compare_extension(x, "Duration", plausible_lower = 10, plausible_upper = 0)
  )
  expect_snapshot(
    error = TRUE,
    compare_extension(x, "Duration", effect_sd = 1e308)
  )
  expect_snapshot(
    error = TRUE,
    compare_extension(elicitation_record(claim("Question", "You")), "Duration")
  )
})
