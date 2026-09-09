measurement_fixture <- function() {
  data.frame(
    observation_id = c("m1", "m2", "m3"),
    condition = c("warm", "warm", "cold"),
    outcome = c(10, 10, NA_real_),
    batch = c("b1", "b1", "b2"),
    specimen = c("s1", "s1", "s2"),
    observed_at = rep("2026-09-08T12:00:00Z", 3)
  )
}
measurement_import <- function(data = measurement_fixture(), ...) {
  import_observations(data, "lab:run-1", "protocol-v1", "Ada", "mV", ...)
}

test_that("conversion preserves originals, missingness, and repeated measurements", {
  d <- measurement_import(
    role = "exploration",
    exposure = "unknown",
    target_units = "V",
    scale = 0.001
  )
  expect_equal(d$rows[[1]]$outcome, 10)
  expect_equal(d$rows[[1]]$converted, 0.01)
  expect_null(d$rows[[3]]$converted)
  expect_equal(d$missing_ids, "m3")
  expect_equal(d$repeated_ids, c("m1", "m2"))
  expect_equal(d$conversion, list(scale = 0.001, offset = 0))
  expect_snapshot(print(d))
})

test_that("CSV import preserves numeric-looking identities and rejects bad outcomes", {
  path <- withr::local_tempfile(fileext = ".csv")
  data <- measurement_fixture()
  data$observation_id <- c("001", "002", "003")
  utils::write.csv(data, path, row.names = FALSE, na = "")
  d <- measurement_import(path, role = "exploration", exposure = "explored")
  expect_equal(d$rows[[1]]$observation_id, "001")
  expect_equal(d$missing_ids, "003")
  expect_equal(nchar(d$file_hash), 64L)
  data$outcome <- c("10", "bad", "")
  utils::write.csv(data, path, row.names = FALSE)
  expect_snapshot(
    error = TRUE,
    measurement_import(path, role = "exploration", exposure = "explored")
  )
})

test_that("previous exposure blocks independent assessment and double updating", {
  expect_snapshot(
    error = TRUE,
    measurement_import(role = "assessment", exposure = "explored")
  )
  expect_snapshot(
    error = TRUE,
    measurement_import(role = "update", exposure = "prior")
  )
  expect_snapshot(
    error = TRUE,
    measurement_import(role = "update", exposure = "unknown")
  )
  expect_equal(
    measurement_import(role = "assessment", exposure = "unseen")$role,
    "assessment"
  )
})

test_that("observations retain their revision and survive conversation and acceptance", {
  c <- claim("A voltage differs", "Ada", units = "mV")
  original <- elicitation_record(c)
  d <- measurement_import(role = "exploration", exposure = "prior")
  attached <- record_observations(
    original,
    d,
    "Inspect previously seen measurements"
  )
  expect_identical(attached$revisions, original$revisions)
  expect_equal(
    observation_inventory(attached)[[1]]$rows_flagged_for_duplicate_review,
    2L
  )
  accepted <- accept_interpretation(
    attached,
    "Ada",
    "Correct scope",
    "Opposite contrast"
  )
  accepted <- record_conversation(accepted, list())
  expect_equal(accepted$schema_version, 4L)
  path <- withr::local_tempfile(fileext = ".json")
  write_record(accepted, path)
  restored <- read_record(path)
  expect_equal(json_data(restored), json_data(accepted))
  expect_s3_class(restored$observations[[1]]$data, "suppose_observations")
  changed <- record_revision(
    restored,
    revise_claim(
      c,
      author = "Ada",
      reason = "New scope",
      wording = "A different voltage differs"
    ),
    reason = "New question"
  )
  expect_equal(changed$observations[[1]]$claim_id, c$id)
  expect_equal(changed$observations[[1]]$revision, 1L)
  expect_equal(
    cli_record_summary(changed)$observations[[1]]$data$missing_ids,
    "m3"
  )
  expect_snapshot(error = TRUE, record_observations(changed, d, "Another copy"))
})

test_that("conversion and claim reference cannot be silently changed", {
  record <- elicitation_record(claim("A voltage differs", "Ada", units = "V"))
  d <- measurement_import(role = "update", exposure = "unseen")
  expect_snapshot(error = TRUE, record_observations(record, d, "Unit mismatch"))
  d <- measurement_import(
    role = "update",
    exposure = "unseen",
    target_units = "V",
    scale = 0.001
  )
  record <- record_observations(record, d, "Converted")
  corrupt <- d
  corrupt$rows[[1]]$converted <- 99
  corrupt$id <- NULL
  corrupt <- seal(unclass(corrupt), "suppose_observations")
  expect_snapshot(
    error = TRUE,
    record_observations(
      elicitation_record(claim("Another", "Ada")),
      corrupt,
      "Tampered"
    )
  )
  record$observations[[1]]$claim_id <- "unknown"
  record$observations[[1]]$id <- NULL
  record$observations[[1]] <- seal(
    unclass(record$observations[[1]]),
    "suppose_evidence"
  )
  expect_snapshot(error = TRUE, validate_record(record))
})

test_that("malformed identities, times and conversions fail before attachment", {
  data <- measurement_fixture()
  data$observation_id[2] <- "m1"
  expect_snapshot(
    error = TRUE,
    measurement_import(data, role = "exploration", exposure = "unknown")
  )
  data <- measurement_fixture()
  data$observed_at[1] <- "2026-02-30T12:00:00Z"
  expect_snapshot(
    error = TRUE,
    measurement_import(data, role = "exploration", exposure = "unknown")
  )
  expect_snapshot(
    error = TRUE,
    measurement_import(role = "exploration", exposure = "unknown", scale = 0)
  )
  expect_snapshot(
    error = TRUE,
    measurement_import(
      role = "exploration",
      exposure = "unknown",
      scale = .Machine$double.xmax
    )
  )
  expect_snapshot(
    error = TRUE,
    measurement_import(
      suppose_example()$revisions[[2]]$prediction,
      role = "exploration",
      exposure = "unknown"
    )
  )
})
