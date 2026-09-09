test_that("predictors match outcome IDs regardless of upload order", {
  f <- regression_fixture()
  d <- regression_predictors(
    f$record,
    f$record$observations[[1]]$id,
    f$data[nrow(f$data):1, ],
    c(temperature = "degC", duration = "minutes"),
    "synthetic:reordered",
    "Analyst"
  )
  expect_identical(d$rows, f$design$rows)
  bad <- f$data
  bad$observation_id[1] <- "different"
  expect_snapshot(
    error = TRUE,
    regression_predictors(
      f$record,
      f$record$observations[[1]]$id,
      bad,
      c(temperature = "degC", duration = "minutes"),
      "source",
      "Analyst"
    )
  )
})

test_that("missing predictor values and ambiguous units are not silently repaired", {
  f <- regression_fixture()
  bad <- f$data
  bad$duration[1] <- NA_real_
  expect_snapshot(
    error = TRUE,
    regression_predictors(
      f$record,
      f$record$observations[[1]]$id,
      bad,
      c(temperature = "degC", duration = "minutes"),
      "source",
      "Analyst"
    )
  )
  expect_snapshot(
    error = TRUE,
    regression_predictors(
      f$record,
      f$record$observations[[1]]$id,
      f$data,
      c("degC", "minutes"),
      "source",
      "Analyst"
    )
  )
})

test_that("CSV imports preserve predictor identities, values and file provenance", {
  f <- regression_fixture(12)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(f$data[12:1, ], path, row.names = FALSE)
  d <- regression_predictors(
    f$record,
    f$record$observations[[1]]$id,
    path,
    c(temperature = "degC", duration = "minutes"),
    "synthetic:csv",
    "Analyst"
  )
  expect_equal(d$rows, f$design$rows)
  expect_match(d$file_hash, "^[a-f0-9]{64}$")
})
