test_that("measurement preview is explicit and stale inputs cannot attach", {
  skip_if_not_installed("shiny")
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      observation_id = "m1",
      condition = "warm",
      outcome = 10,
      batch = "b1",
      specimen = "s1",
      observed_at = "2026-09-08T12:00:00Z"
    ),
    path,
    row.names = FALSE
  )
  original <- elicitation_record(claim(
    "A voltage differs",
    "Ada",
    units = "mV"
  ))
  current <- shiny::reactiveVal(original)
  shiny::testServer(
    observations_server,
    args = list(current = current, guard = function() NULL),
    {
      session$setInputs(
        csv = list(datapath = path),
        source = "lab:1",
        protocol = "v1",
        author = "Ada",
        units = "mV",
        role = "exploration",
        exposure = "unknown",
        target_units = "",
        scale = 1,
        offset = 0,
        reason = "Inspect",
        preview = 1
      )
      expect_identical(current(), original)
      expect_equal(length(staged()$data$rows), 1L)
      session$setInputs(reason = "Changed", attach = 1)
      expect_identical(current(), original)
      expect_match(status(), "Preview the import again")
      session$setInputs(preview = 2)
      session$setInputs(attach = 2)
      expect_equal(length(current()$observations), 1L)
      expect_identical(current()$revisions, original$revisions)
      session$setInputs(preview = 3)
      expect_match(status(), "already attached")
      expect_equal(length(current()$observations), 1L)
    }
  )
})

test_that("changed claims and busy sessions cannot use earlier measurement previews", {
  skip_if_not_installed("shiny")
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      observation_id = "m1",
      condition = "warm",
      outcome = 10,
      batch = "b1",
      specimen = "s1",
      observed_at = "2026-09-08T12:00:00Z"
    ),
    path,
    row.names = FALSE
  )
  original <- elicitation_record(claim(
    "A voltage differs",
    "Ada",
    units = "mV"
  ))
  current <- shiny::reactiveVal(original)
  running <- new.env()
  running$value <- FALSE
  guard <- function() {
    if (running$value) abort_suppose("Finish the response first.", "busy")
  }
  shiny::testServer(
    observations_server,
    args = list(current = current, guard = guard),
    {
      session$setInputs(
        csv = list(datapath = path),
        source = "lab:1",
        protocol = "v1",
        author = "Ada",
        units = "mV",
        role = "exploration",
        exposure = "unknown",
        target_units = "",
        scale = 1,
        offset = 0,
        reason = "Inspect",
        preview = 1
      )
      current(accept_interpretation(
        current(),
        "Ada",
        "Correct",
        "A reversed difference"
      ))
      session$setInputs(attach = 1)
      expect_length(current()$observations, 0L)
      expect_match(status(), "claim changed")
      session$setInputs(preview = 2)
      running$value <- TRUE
      session$setInputs(attach = 2)
      expect_length(current()$observations, 0L)
      expect_match(status(), "Finish the response")
    }
  )
})

test_that("missing CSV selection produces an actionable visible message", {
  skip_if_not_installed("shiny")
  current <- shiny::reactiveVal(elicitation_record(claim(
    "Voltage differs",
    "Ada"
  )))
  shiny::testServer(
    observations_server,
    args = list(current = current, guard = function() NULL),
    {
      session$setInputs(preview = 1)
      expect_equal(status(), "Choose a measurements CSV before previewing.")
      expect_null(staged())
      expect_length(current()$observations, 0L)
    }
  )
})
