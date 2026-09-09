test_that("commitments freeze the actual planned-sample predictive distribution", {
  f <- prospective_fixture()
  p <- f$before$revisions[[3]]$candidate
  variance <- sum(p$mean_sd^2) -
    2 * p$correlation * prod(p$mean_sd) +
    sum(p$batch_sd^2 / 2)
  expect_equal(f$c$prediction$sd, sqrt(variance))
  expect_equal(f$c$prediction$mean, diff(p$means))
  expect_equal(
    c(f$c$prediction$lower, f$c$prediction$upper),
    diff(p$means) + qnorm(c(0.05, 0.95)) * sqrt(variance)
  )
  expect_identical(f$c$prediction$planned_n, c(2L, 2L))
  expect_identical(f$record$revisions, f$before$revisions)
  expect_length(f$c$basis_observation_ids, 0)
  path <- tempfile(fileext = ".json")
  write_record(f$record, path)
  expect_identical(json_data(read_record(path)), json_data(f$record))
})

test_that("a selected update is frozen as an explicit prediction basis", {
  f <- prospective_fixture(updated = TRUE)
  u <- f$before$updates[[1]]
  covariance <- matrix(u$result$posterior$covariance, 2)
  expected_variance <- sum(diag(covariance)) - 2 * covariance[1, 2] + 9
  expect_identical(f$c$update_id, u$id)
  expect_identical(f$c$basis_observation_ids, u$result$observation_ids)
  expect_equal(f$c$prediction$mean, diff(u$result$posterior$means))
  expect_equal(f$c$prediction$sd, sqrt(expected_variance))
  expect_identical(f$record$updates, f$before$updates)
})

test_that("both designs assess a complete cohort without refitting or asserting truth", {
  for (design in c("observational", "intervention")) {
    f <- prospective_fixture(design)
    x <- record_observations(
      f$record,
      prospective_observations(f),
      "Designated outcomes"
    )
    out <- assess_test(x, f$c$id, "Reviewer", "All outcomes collected", TRUE)
    a <- out$assessments[[1]]
    expect_identical(a$status, "within_prediction")
    expect_equal(a$observed$difference, 8)
    expect_identical(a$observed$n, c(2L, 2L))
    expect_identical(out$commitments, x$commitments)
    expect_identical(out$revisions, x$revisions)
    expect_match(
      a$interpretation,
      "not whether the claim is true",
      fixed = TRUE
    )
    expect_identical(a$evidence_ids, x$observations[[1]]$id)
    path <- tempfile(fileext = ".json")
    write_record(out, path)
    reopened <- read_record(path)
    expect_identical(json_data(reopened), json_data(out))
    expect_s3_class(reopened$commitments[[1]], "suppose_test_commitment")
    expect_s3_class(reopened$assessments[[1]], "suppose_test_assessment")
  }
})

test_that("outside predictions and inclusive boundary results follow the frozen rule", {
  f <- prospective_fixture()
  for (difference in c(f$c$prediction$lower, f$c$prediction$upper, 100)) {
    x <- record_observations(
      f$record,
      prospective_observations(f, c(0, 0, difference, difference)),
      "Fixed cohort"
    )
    a <- assess_test(x, f$c$id, "Reviewer", "Compare", TRUE)$assessments[[1]]
    expect_identical(
      a$status,
      if (difference == 100) "outside_prediction" else "within_prediction"
    )
    expect_equal(a$observed$difference, difference)
  }
})

test_that("missing outcomes wait until the horizon and preserve earlier assessments", {
  f <- prospective_fixture()
  x <- record_observations(
    f$record,
    prospective_observations(f, rows = 1:2),
    "First outcomes"
  )
  x <- assess_test(x, f$c$id, "Reviewer", "Check arrival", TRUE)
  expect_identical(x$assessments[[1]]$status, "awaiting_outcomes")
  expect_identical(x$assessments[[1]]$missing_ids, c("b1", "b2"))
  expect_null(x$assessments[[1]]$observed)
  f$clock$now <- f$c$horizon
  out <- assess_test(x, f$c$id, "Reviewer", "Deadline reached", TRUE)
  expect_identical(out$assessments[[2]]$status, "inconclusive")
  expect_identical(out$assessments[[2]]$supersedes, x$assessments[[1]]$id)
  expect_identical(out$assessments[[1]], x$assessments[[1]])
  # Import may be later; the actual measurements still must be inside the window.
  f$clock$now <- "2026-01-04T12:00:00Z"
  out <- record_observations(
    out,
    prospective_observations(f, rows = 3:4),
    "Delayed entry of timely outcomes"
  )
  out <- assess_test(out, f$c$id, "Reviewer", "Complete original cohort", TRUE)
  expect_identical(out$assessments[[3]]$status, "within_prediction")
  expect_identical(out$assessments[[3]]$supersedes, out$assessments[[2]]$id)
  expect_identical(out$commitments, f$record$commitments)
  expect_snapshot(
    error = TRUE,
    assess_test(out, f$c$id, "Reviewer", "Repeated click", TRUE)
  )
})

test_that("explicit missing values receive no partial numerical comparison", {
  f <- prospective_fixture()
  x <- record_observations(
    f$record,
    prospective_observations(f, c(49, NA, 57, 59)),
    "Missing outcome"
  )
  a <- assess_test(
    x,
    f$c$id,
    "Reviewer",
    "Check completeness",
    TRUE
  )$assessments[[1]]
  expect_identical(a$status, "awaiting_outcomes")
  expect_identical(a$missing_ids, "a2")
  expect_null(a$observed)
})

test_that("unplanned observations cannot change the predeclared sample", {
  f <- prospective_fixture()
  o <- prospective_observations(f)
  x <- record_observations(f$record, o, "Planned outcomes")
  extra <- import_observations(
    data.frame(
      observation_id = "unplanned",
      condition = "other",
      outcome = 1e6,
      batch = "extra",
      specimen = "extra",
      observed_at = "2026-01-02T10:00:00Z"
    ),
    source = f$c$source,
    protocol = f$c$protocol,
    author = "Analyst",
    units = "MPa",
    role = "assessment",
    exposure = "unseen"
  )
  x <- record_observations(x, extra, "Additional data outside plan")
  a <- assess_test(
    x,
    f$c$id,
    "Reviewer",
    "Use exact planned IDs",
    TRUE
  )$assessments[[1]]
  expect_equal(a$observed$difference, 8)
  expect_identical(a$excluded_ids, "unplanned")
  expect_identical(a$observation_ids, o$id)
})

test_that("unverified timing prevents assessment instead of silently dropping rows", {
  f <- prospective_fixture()
  cases <- c(
    unknown = "unknown_observation_time",
    `2026-01-01T12:00:00Z` = "outcome_before_or_at_commitment",
    `2026-01-04T00:00:00Z` = "outcome_after_deadline",
    `2026-01-02T18:00:00Z` = "future_dated_outcome"
  )
  for (time in names(cases)) {
    x <- record_observations(
      f$record,
      prospective_observations(f, time = time),
      "Timing case"
    )
    a <- assess_test(x, f$c$id, "Reviewer", "Check timing", TRUE)$assessments[[
      1
    ]]
    expect_identical(a$status, "inconclusive")
    expect_contains(a$issues, cases[[time]])
    expect_null(a$observed)
  }
})

test_that("exposure, protocol, conversion and adherence remain substantive checks", {
  f <- prospective_fixture()
  cases <- list(
    list(protocol = "different"),
    list(role = "exploration", exposure = "explored"),
    list(scale = 2)
  )
  issues <- c(
    "protocol_identifier_mismatch",
    "ineligible_evidence_exposure",
    "units_or_conversion_mismatch"
  )
  for (i in seq_along(cases)) {
    o <- do.call(prospective_observations, c(list(f = f), cases[[i]]))
    x <- record_observations(f$record, o, "Ineligible observations")
    a <- assess_test(
      x,
      f$c$id,
      "Reviewer",
      "Review eligibility",
      TRUE
    )$assessments[[1]]
    expect_identical(a$status, "inconclusive")
    expect_contains(a$issues, issues[i])
    expect_null(a$observed)
  }
  x <- record_observations(
    f$record,
    prospective_observations(f),
    "Unconfirmed adherence"
  )
  a <- assess_test(x, f$c$id, "Reviewer", "Adherence unknown")$assessments[[1]]
  expect_identical(a$status, "inconclusive")
  expect_identical(a$issues, "protocol_adherence_unconfirmed")
  expect_null(a$observed)
})

test_that("later claim revisions never change the original assessment basis", {
  f <- prospective_fixture()
  old <- utils::tail(f$record$revisions, 1)[[1]]$claim
  revised <- revise_claim(
    old,
    author = "Analyst",
    reason = "New interpretation",
    wording = "A different question about the same units."
  )
  x <- record_revision(f$record, revised, reason = "Revise the claim")
  x <- record_observations(x, prospective_observations(f), "Later outcomes")
  out <- assess_test(x, f$c$id, "Reviewer", "Assess original prediction", TRUE)
  expect_identical(out$assessments[[1]]$status, "within_prediction")
  expect_identical(out$commitments, f$record$commitments)
  expect_identical(out$observations[[1]]$revision, 4L)
  expect_identical(out$commitments[[1]]$revision, 3L)
})

test_that("plan revisions retain ancestry and cannot reuse already attached outcomes", {
  f <- prospective_fixture()
  new <- commit_test(
    f$record,
    f$plan,
    c(low = 140, high = 160),
    f$c$source,
    f$c$protocol,
    f$c$horizon,
    "Analyst",
    "Wider predictive interval before outcomes",
    design_details = "Unchanged independent protocol",
    independent = TRUE,
    outcomes_unseen = TRUE,
    coverage = 0.95,
    replaces = f$c$id
  )
  expect_identical(new$commitments[[1]], f$c)
  expect_identical(new$commitments[[2]]$replaces, f$c$id)
  expect_gt(new$commitments[[2]]$prediction$upper, f$c$prediction$upper)
  x <- record_observations(
    f$record,
    prospective_observations(f),
    "Examined outcomes"
  )
  expect_snapshot(
    error = TRUE,
    commit_test(
      x,
      f$plan,
      c(low = 140, high = 160),
      f$c$source,
      f$c$protocol,
      f$c$horizon,
      "Analyst",
      "Try to recommit",
      design_details = "Same protocol",
      independent = TRUE,
      outcomes_unseen = TRUE
    )
  )
})

test_that("commitment review requires an unexpired deadline and explicit declarations", {
  f <- prospective_fixture()
  expect_snapshot(
    error = TRUE,
    commit_test(
      f$before,
      f$plan,
      c(low = 140, high = 160),
      f$c$source,
      f$c$protocol,
      f$c$horizon,
      "Analyst",
      "A test",
      design_details = "Protocol"
    )
  )
  expect_snapshot(
    error = TRUE,
    commit_test(
      f$before,
      f$plan,
      c(low = 140, high = 160),
      f$c$source,
      f$c$protocol,
      "2026-01-01T12:00:00Z",
      "Analyst",
      "A test",
      design_details = "Protocol",
      independent = TRUE,
      outcomes_unseen = TRUE
    )
  )
  expect_snapshot(error = TRUE, test_time("2026-02-30T12:00:00Z", "deadline"))
  expect_snapshot(
    error = TRUE,
    test_plan(
      transform(f$plan, observation_id = "same"),
      c(low = 140, high = 160),
      c(140, 160)
    )
  )
  expect_snapshot(
    error = TRUE,
    test_plan(f$plan, c(low = 0, high = 1), c(140, 160))
  )
})

test_that("saved commitment tampering is detected", {
  f <- prospective_fixture()
  x <- f$record
  x$commitments[[1]]$prediction$upper <- 1e6
  expect_snapshot(error = TRUE, validate_record(x))
  x <- f$record
  c <- x$commitments[[1]]
  c$id <- NULL
  c$claim_id <- "not-in-record"
  x$commitments[[1]] <- seal(c, "suppose_test_commitment")
  expect_snapshot(error = TRUE, validate_record(x))
})
