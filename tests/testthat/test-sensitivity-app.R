test_that("chat fills sensitivity controls and retains its reviewed provenance", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  f <- sensitivity_fixture()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      incoming <- shiny::reactiveVal(NULL)
      state <- sensitivity_server(
        "s",
        current,
        function() NULL,
        draft = incoming
      )
    },
    {
      session$setInputs(
        `s-update_id` = f$update$id,
        `s-powers` = "0.8, 1, 1.25",
        `s-components` = c("prior", "likelihood"),
        `s-quantities` = c("estimate", "probability", "assessment"),
        `s-estimate_change` = 1,
        `s-probability_change` = 5,
        `s-reason` = "Review strength"
      )
      chat <- form_session(f$record, list(sensitivity = state$form_state()))
      id <- chat$session$begin("Check prior strength only.")
      chat$session$tools(id)[[6]](
        "Check prior strength only.",
        "Review prior influence",
        components = "prior"
      )
      chat$session$finish(id, "Prepared.")
      d <- chat$published$drafts$sensitivity
      incoming(d)
      session$flushReact()
      expect_s3_class(state$staged()$fit, "suppose_sensitivity")
      expect_length(current()$sensitivities, 0)
      session$setInputs(
        `s-components` = "prior",
        `s-reason` = d$reason,
        `s-estimate_change` = 1L,
        `s-probability_change` = 5L
      )
      session$setInputs(`s-retain` = 1)
      expect_length(current()$sensitivities, 1)
      expect_identical(current()$sensitivities[[1]]$form_draft, d)
      expect_identical(current()$updates, f$record$updates)
    }
  )
})

test_that("sensitivity preview guards changes and retained findings draft follow-up", {
  skip_if_no_app()
  f <- sensitivity_fixture()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      drafted <- shiny::reactiveVal(NULL)
      state <- sensitivity_server(
        "s",
        current,
        function() NULL,
        function(text) drafted(text)
      )
    },
    {
      session$setInputs(
        `s-update_id` = f$update$id,
        `s-powers` = "0.8, 1, 1.25",
        `s-components` = c("prior", "likelihood"),
        `s-quantities` = c("estimate", "probability"),
        `s-estimate_change` = 1,
        `s-probability_change` = 5,
        `s-reason` = "Review strength"
      )
      session$setInputs(`s-preview` = 1)
      expect_s3_class(state$staged()$fit, "suppose_sensitivity")
      expect_length(current()$sensitivities, 0)
      session$setInputs(`s-powers` = "0.9,1,1.1", `s-retain` = 1)
      expect_match(state$status(), "changed")
      expect_length(current()$sensitivities, 0)
      session$setInputs(`s-preview` = 2)
      session$setInputs(`s-retain` = 2)
      expect_length(current()$sensitivities, 1)
      expect_identical(current()$updates, f$record$updates)
      expect_null(state$staged())
      session$setInputs(`s-followup` = 1)
      expect_match(
        drafted(),
        current()$sensitivities[[1]]$result$id,
        fixed = TRUE
      )
      expect_match(drafted(), "review the assumptions")
      session$setInputs(`s-preview` = 3)
      expect_s3_class(state$staged()$fit, "suppose_sensitivity")
      current(NULL)
      session$flushReact()
      expect_null(state$staged())
    }
  )
})

test_that("sensitivity UI rejects malformed powers and stale record previews", {
  skip_if_no_app()
  f <- sensitivity_fixture()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      state <- sensitivity_server("s", current, function() NULL)
    },
    {
      session$setInputs(
        `s-update_id` = f$update$id,
        `s-powers` = "0.8, 1,",
        `s-components` = "prior",
        `s-quantities` = "estimate",
        `s-estimate_change` = 1,
        `s-probability_change` = 5,
        `s-reason` = "Review strength",
        `s-preview` = 1
      )
      expect_match(state$status(), "comma-separated")
      expect_null(state$staged())
      session$setInputs(`s-powers` = "0.8,1,1.25", `s-preview` = 2)
      changed <- record_revision(
        current(),
        f$prior$claim,
        reason = "New review"
      )
      current(changed)
      session$flushReact()
      session$setInputs(`s-retain` = 1)
      expect_match(state$status(), "changed")
      expect_length(current()$sensitivities, 0)
    }
  )
})
