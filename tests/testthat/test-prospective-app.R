test_that("commitment previews cannot backdate or retain changed plans", {
  skip_if_no_app()
  f <- prospective_fixture()
  f$clock$now <- "2026-01-01T13:00:00Z"
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$before)
      state <- prospective_server("future", current, function() NULL)
    },
    {
      session$setInputs(
        `future-low_label` = "low",
        `future-high_label` = "high",
        `future-low_ids` = "a1\na2",
        `future-high_ids` = "b1\nb2",
        `future-source` = f$c$source,
        `future-protocol` = f$c$protocol,
        `future-design` = "observational",
        `future-design_details` = "Independent future units",
        `future-deadline_date` = as.Date("2026-01-03"),
        `future-deadline_time` = "12:00:00",
        `future-coverage` = 90,
        `future-author` = "Reviewer",
        `future-reason` = "A planned comparison",
        `future-independent` = TRUE,
        `future-unseen` = TRUE
      )
      session$setInputs(`future-preview` = 1)
      expect_length(current()$commitments, 0)
      expect_identical(
        state$draft()$commitment$created_at,
        "2026-01-01T13:00:00Z"
      )
      session$setInputs(`future-coverage` = 95, `future-freeze` = 1)
      expect_match(state$status(), "changed")
      expect_length(current()$commitments, 0)
      session$setInputs(`future-preview` = 2)
      f$clock$now <- "2026-01-01T14:00:00Z"
      session$setInputs(`future-freeze` = 2)
      expect_length(current()$commitments, 1)
      expect_identical(current()$commitments[[1]]$created_at, f$clock$now)
      expect_equal(current()$commitments[[1]]$prediction$coverage, 0.95)
      expect_identical(current()$revisions, f$before$revisions)
      expect_null(state$draft())
    }
  )
})

test_that("assessment review rejects changed inputs and a crossed deadline", {
  skip_if_no_app()
  f <- prospective_fixture()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      state <- prospective_server("future", current, function() NULL)
    },
    {
      session$setInputs(
        `future-assess_id` = f$c$id,
        `future-assessor` = "Reviewer",
        `future-assessment_reason` = "Check completeness",
        `future-protocol_followed` = FALSE
      )
      session$setInputs(`future-preview_assessment` = 1)
      expect_identical(state$assessment()$result$status, "awaiting_outcomes")
      f$clock$now <- "2026-01-04T12:00:00Z"
      session$setInputs(`future-retain_assessment` = 1)
      expect_match(state$status(), "time passed")
      expect_length(current()$assessments, 0)
      session$setInputs(`future-preview_assessment` = 2)
      session$setInputs(
        `future-assessment_reason` = "Change reason",
        `future-retain_assessment` = 2
      )
      expect_match(state$status(), "inputs changed")
      expect_length(current()$assessments, 0)
      session$setInputs(`future-preview_assessment` = 3)
      session$setInputs(`future-retain_assessment` = 3)
      expect_length(current()$assessments, 1)
      expect_identical(current()$assessments[[1]]$status, "inconclusive")
      expect_identical(current()$commitments, f$record$commitments)
    }
  )
})

test_that("conversation changes clear previews but ordinary record changes do not", {
  skip_if_no_app()
  f <- prospective_fixture()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      state <- prospective_server("future", current, function() NULL)
    },
    {
      session$setInputs(
        `future-assess_id` = f$c$id,
        `future-assessor` = "Reviewer",
        `future-assessment_reason` = "Review missing outcomes",
        `future-protocol_followed` = TRUE,
        `future-preview_assessment` = 1
      )
      expect_false(is.null(state$assessment()))
      current(record_observations(
        current(),
        prospective_observations(f),
        "Later data"
      ))
      session$flushReact()
      expect_false(is.null(state$assessment()))
      current(NULL)
      session$flushReact()
      expect_null(state$assessment())
      expect_null(state$draft())
    }
  )
})
