table_fixture <- function() {
  csv <- paste(
    "batch,temp,time,life",
    "B01,50,20,77",
    "B02,50,30,97",
    "B03,60,20,87",
    "B04,60,30,101",
    "B05,70,30,109",
    "B06,70,40,125",
    sep = "\n"
  )
  x <- elicitation_record(claim(
    "Hotter drying may help",
    "You",
    units = "cycles"
  ))
  values <- workbench_form_values(
    x,
    "import",
    list(
      csv_text = csv,
      id_column = "batch",
      outcome_column = "life",
      predictor_columns = c("temp", "time"),
      predictor_units = c("degC", "minutes"),
      batch_column = "batch",
      source = "Fictional pilot",
      protocol = "Same coating protocol",
      units = "cycles",
      role = "update",
      exposure = "explored",
      collection_note = "Collected 2026-09-01; convenient settings"
    )
  )
  list(record = x, csv = csv, values = values)
}

test_that("chat stages one exact table with linked outcomes and predictors", {
  skip_if_not_installed("ellmer")
  f <- table_fixture()
  s <- form_session(f$record)
  id <- s$session$begin(paste("Here is my fictional pilot.", f$csv, sep = "\n"))
  t <- s$session$tools(id)[[8]]
  out <- do.call(
    t,
    c(list(source_quote = f$csv, reason = "Explore this pilot"), f$values)
  )
  expect_match(out, '"rows":6', fixed = TRUE)
  expect_length(s$published$drafts, 0)
  expect_length(f$record$observations, 0)
  s$session$finish(id, "Review the table.")
  draft <- s$published$drafts$import
  p <- measurement_form_preview(f$record, draft$values, draft)
  expect_length(p$record$observations, 1)
  expect_length(p$record$predictors, 1)
  expect_identical(p$record$revisions, f$record$revisions)
  a <- p$record$observations[[1]]
  expect_identical(p$record$predictors[[1]]$evidence_id, a$id)
  expect_identical(a$table_import$values$csv_text, f$csv)
  expect_identical(a$table_import$form_draft$context$status, "complete")
  expect_identical(a$data$rows[[1]]$observed_at, "unknown")
  expect_identical(
    a$table_import$values$collection_note,
    f$values$collection_note
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_record(p$record, path)
  expect_identical(json_data(read_record(path)), json_data(p$record))
  # These are fit-eligible measurements, not an automatically fitted model.
  prior <- regression_prior(
    p$record,
    p$predictors$id,
    c("temp", "time"),
    location = 100
  )
  fit <- fit_regression(
    p$record,
    prior,
    independent = TRUE,
    reviewed = TRUE,
    draws = 200
  )
  expect_length(fit$fits, 2)
  expect_length(p$record$regressions, 0)
})

test_that("prior change previews expose excessive shrinkage and exclude observation noise", {
  skip_if_not_installed("shiny")
  f <- table_fixture()
  p <- measurement_form_preview(f$record, f$values)
  spec <- regression_prior(
    p$record,
    p$predictors$id,
    "temp",
    location = 100,
    effect_sd = 1,
    noise_sd = 10
  )
  delta <- spec$prior_changes[[1]]
  expect_equal(c(delta$from, delta$to), c(50, 70))
  expect_equal(
    c(delta$lower, delta$upper),
    2 * stats::qt(c(0.05, 0.95), df = 6) * sqrt(2 / 3)
  )
  noisier <- regression_prior(
    p$record,
    p$predictors$id,
    "temp",
    location = 100,
    effect_sd = 1,
    noise_sd = 50
  )
  expect_equal(noisier$prior_changes, spec$prior_changes)
  broader <- regression_prior(
    p$record,
    p$predictors$id,
    "temp",
    location = 100,
    effect_sd = 10
  )
  expect_equal(broader$prior_changes[[1]]$upper, 10 * delta$upper)
  expect_match(as.character(regression_prior_details(spec)), "mean change")
})

test_that("table import rejects invented data and unusable column mappings", {
  f <- table_fixture()
  expect_snapshot(error = TRUE, measurement_table("id,x,y\na,1,2,3"))
  expect_snapshot(
    error = TRUE,
    measurement_source_check(
      sub("77", "78", f$csv),
      list(list(role = "user", text = f$csv))
    )
  )
  expect_invisible(measurement_source_check(
    f$csv,
    list(list(role = "user", text = gsub("\n", "", f$csv)))
  ))
  v <- f$values
  v$predictor_columns <- c("temp", "life")
  expect_snapshot(error = TRUE, measurement_form_preview(f$record, v))
  v <- f$values
  v$exposure <- "prior"
  expect_snapshot(error = TRUE, measurement_form_preview(f$record, v))
  v <- f$values
  v$csv_text <- sub("77", "oops", v$csv_text)
  expect_snapshot(error = TRUE, measurement_form_preview(f$record, v))
  v <- f$values
  v$csv_text <- sub("B02", "B01", v$csv_text)
  expect_snapshot(error = TRUE, measurement_form_preview(f$record, v))
})

test_that("cancelled import drafts cannot publish and edited previews cannot attach", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  f <- table_fixture()
  s <- form_session(f$record)
  id <- s$session$begin(f$csv)
  do.call(
    s$session$tools(id)[[8]],
    c(list(source_quote = f$csv, reason = "Explore"), f$values)
  )
  s$session$cancel()
  expect_length(s$published$drafts, 0)
  current <- shiny::reactiveVal(f$record)
  shiny::testServer(
    measurement_import_server,
    args = list(current = current, guard = function() NULL),
    {
      v <- f$values
      v$predictor_columns <- paste(v$predictor_columns, collapse = ", ")
      v$predictor_units <- paste(v$predictor_units, collapse = ", ")
      do.call(session$setInputs, c(v, list(preview = 1)))
      expect_length(staged()$result$record$predictors, 1)
      expect_identical(current(), f$record)
      session$setInputs(
        collection_note = "Corrected collection detail",
        attach = 1
      )
      expect_identical(current(), f$record)
      expect_match(status(), "Preview again")
      session$setInputs(preview = 2)
      session$setInputs(attach = 2)
      expect_length(current()$observations, 1)
      expect_length(current()$predictors, 1)
      expect_identical(
        current()$observations[[1]]$table_import$values$collection_note,
        "Corrected collection detail"
      )
      session$setInputs(attach = 3)
      expect_length(current()$observations, 1)
    }
  )
})

test_that("native history preserves table drafts and concurrent edits need review", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  f <- table_fixture()
  s <- form_session(
    f$record,
    list(import = list(values = f$values, version = "old-form"))
  )
  id <- s$session$begin(f$csv)
  s$session$tools(id)[[8]](f$csv, "Preview the existing table")
  s$session$finish(id, "Review")
  draft <- s$published$drafts$import
  restored <- decode_inquiry_history(encode_inquiry_history(
    f$record,
    NULL,
    s$session$messages,
    forms = list(import = draft)
  ))
  expect_identical(json_data(restored$forms$import), json_data(draft))
  current <- shiny::reactiveVal(f$record)
  shiny::testServer(
    measurement_import_server,
    args = list(current = current, guard = function() NULL, draft = function() {
      draft
    }),
    {
      session$flushReact()
      expect_match(status(), "inputs changed")
      expect_null(staged())
      session$setInputs(use_draft = 1)
      expect_equal(length(staged()$result$data$rows), 6)
      expect_length(current()$observations, 0)
    }
  )
})
