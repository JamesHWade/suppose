test_that("agent tools stage actual form values only after successful completion", {
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  f <- form_session(x)
  s <- f$session
  text <- "Add duration in minutes, centered at 60 with a meaningful change of 10."
  id <- s$begin(text)
  tools <- s$tools(id)
  result <- jsonlite::fromJSON(tools[[5]](
    "Duration",
    text,
    "Longer curing may change strength",
    predictor_units = "minutes",
    center = 60,
    scale = 10
  ))
  expect_identical(result$form, "extension")
  expect_equal(result$values$scale, 10)
  expect_match(result$status, "no scientific record has changed")
  expect_length(f$published$drafts, 0)
  expect_null(s$pending)
  s$finish(id, "The form is ready to review.")
  d <- f$published$drafts$extension
  expect_s3_class(d, "suppose_form_draft")
  expect_identical(d$source_quote, text)
  expect_equal(d$values$center, 60)
  expect_equal(d$values$scale, 10)
  expect_identical(d$context$status, "complete")
  expect_length(x$model_extensions, 0)
  expect_null(s$pending)
  encoded <- encode_inquiry_history(
    x,
    NULL,
    s$messages,
    forms = list(extension = d)
  )
  decoded <- decode_inquiry_history(encoded)
  expect_identical(json_data(decoded$forms$extension), json_data(d))
  comparison <- workbench_form_preview(x, "extension", d$values)$fit
  retained <- record_extension(
    x,
    comparison,
    "Reviewer",
    d$reason,
    reviewed = TRUE,
    form_draft = d
  )
  path <- tempfile(fileext = ".json")
  write_record(retained, path)
  expect_identical(json_data(read_record(path)), json_data(retained))
})

test_that("form tools preserve existing inputs instead of resetting omitted fields", {
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  values <- workbench_form_values(
    x,
    "extension",
    list(
      predictor = "Duration",
      center = 60,
      scale = 10,
      predictor_units = "minutes"
    )
  )
  f <- form_session(
    x,
    list(extension = list(values = values, version = "existing-form-version"))
  )
  id <- f$session$begin("Set the added effect SD to 2 for duration.")
  f$session$tools(id)[[5]](
    "Duration",
    "Set the added effect SD to 2 for duration.",
    "Review the effect spread",
    effect_sd = 2
  )
  f$session$finish(id, "Updated the form draft.")
  d <- f$published$drafts$extension
  expect_equal(d$values$center, 60)
  expect_equal(d$values$scale, 10)
  expect_equal(d$values$effect_sd, 2)
  expect_identical(d$form_base_id, "existing-form-version")
  expect_contains(d$preserved_fields, c("center", "scale", "predictor_units"))
})

test_that("cancelled and stale tool requests cannot publish form changes", {
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  published <- list()
  s <- new_proposal_session(
    function() x,
    general = TRUE,
    publish_form = function(d) {
      published[[d$form]] <<- d
    }
  )
  id <- s$begin("Add duration.")
  s$tools(id)[[5]]("Duration", "Add duration.", "Consider an added predictor")
  s$cancel()
  expect_length(published, 0)
  id <- s$begin("Add duration.")
  tools <- s$tools(id)
  x <- record_revision(x, x$revisions[[3]]$claim, reason = "New review")
  expect_snapshot(
    error = TRUE,
    tools[[5]]("Duration", "Add duration.", "Consider duration")
  )
  expect_length(published, 0)
})

test_that("sensitivity can be drafted without a questionnaire and retained with provenance", {
  skip_if_not_installed("ellmer")
  x <- sensitivity_fixture()$record
  f <- form_session(x)
  id <- f$session$begin("Check whether the conclusion depends on my prior.")
  reply <- jsonlite::fromJSON(f$session$tools(id)[[6]](
    "Check whether the conclusion depends on my prior.",
    "Review prior dependence"
  ))
  expect_identical(reply$form, "sensitivity")
  expect_equal(reply$values$powers, c(0.8, 1, 1.25))
  f$session$finish(id, "Prepared the sensitivity form.")
  d <- f$published$drafts$sensitivity
  fit <- workbench_form_preview(x, "sensitivity", d$values)$fit
  saved <- record_sensitivity(x, fit, d$reason, form_draft = d)
  expect_identical(saved$sensitivities[[1]]$form_draft, d)
  expect_length(saved$updates, 1)
})
