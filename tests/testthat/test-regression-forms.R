test_that("regression form drafts survive native history without fitting", {
  f <- regression_fixture(12)
  chat <- form_session(f$record)
  request <- "Prepare a temperature regression with duration added."
  id <- chat$session$begin(request)
  chat$session$tools(id)[[7]](
    request,
    "Inspect predictor effects",
    predictors = c("temperature", "duration"),
    location = 54
  )
  expect_length(chat$published$drafts, 0)
  chat$session$finish(id, "Prepared the form.")
  draft <- chat$published$drafts$regression
  encoded <- encode_inquiry_history(
    f$record,
    NULL,
    chat$session$messages,
    forms = list(regression = draft)
  )
  restored <- decode_inquiry_history(encoded)
  expect_identical(restored$forms$regression$id, draft$id)
  expect_identical(
    restored$forms$regression$values$predictors,
    c("temperature", "duration")
  )
  expect_length(restored$record$regressions, 0)
})

test_that("regression drafting clearly requests missing predictor measurements", {
  chat <- form_session(suppose_example())
  id <- chat$session$begin("Prepare a regression.")
  expect_snapshot(
    error = TRUE,
    chat$session$tools(id)[[7]]("Prepare a regression.", "Review a model")
  )
  expect_length(chat$published$drafts, 0)
})

test_that("reopening uses the latest reviewed model settings rather than generic priors", {
  f <- regression_fixture(12)
  spec <- regression_test_prior(f)
  result <- fit_regression(f$record, spec, TRUE, TRUE, draws = 200)
  x <- record_regression(
    f$record,
    result,
    "extended",
    "Reviewer",
    "Keep this model for comparison",
    TRUE
  )
  restored <- decode_inquiry_history(encode_inquiry_history(
    x,
    NULL,
    list()
  ))$record
  defaults <- regression_form_defaults(restored)
  expect_identical(defaults$predictors, c("temperature", "duration"))
  expect_equal(defaults$effect_sd, 20)
  expect_equal(defaults$noise_sd, 3)
  expect_equal(defaults$location, 54)
})
