test_that("chat prepares prior controls, human fits and retains a reviewed comparison", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  f <- regression_fixture(12)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      draft <- shiny::reactiveVal(NULL)
      controller <- regression_server(
        "r",
        current,
        function() NULL,
        draft = draft
      )
    },
    {
      session$setInputs(
        `r-design_id` = f$design$id,
        `r-baseline` = "temperature",
        `r-added` = "",
        `r-location` = 54,
        `r-intercept_sd` = 10,
        `r-effect_sd` = 20,
        `r-noise_sd` = 3,
        `r-noise_shape` = 3
      )
      chat <- form_session(f$record, list(regression = controller$form_state()))
      request <- "Add duration to the temperature regression and prepare its priors."
      id <- chat$session$begin(request)
      chat$session$tools(id)[[7]](
        request,
        "Check the omitted duration pattern",
        predictors = c("temperature", "duration")
      )
      expect_null(controller$prior())
      chat$session$finish(id, "Prepared.")
      draft(chat$published$drafts$regression)
      session$flushReact()
      expect_s3_class(controller$prior()$spec, "suppose_regression_spec")
      expect_null(controller$result())
      expect_length(current()$regressions, 0)
      session$setInputs(
        `r-added` = "duration",
        `r-location` = 54L,
        `r-noise_shape` = 3L
      )
      session$setInputs(`r-fit` = 1)
      expect_match(controller$status(), "confirm independent")
      session$setInputs(`r-independent` = TRUE, `r-fit` = 2)
      expect_s3_class(controller$result(), "suppose_regression")
      session$setInputs(
        `r-choice` = "extended",
        `r-reason` = "Better predictions with duration; retain observational limits",
        `r-retain` = 1
      )
      expect_length(current()$regressions, 1)
      expect_identical(
        current()$regressions[[1]]$form_draft,
        chat$published$drafts$regression
      )
      expect_null(controller$result())
    }
  )
})

test_that("regression drafts protect concurrent edits and restore without fitting", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  f <- regression_fixture(12)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      draft <- shiny::reactiveVal(NULL)
      controller <- regression_server(
        "r",
        current,
        function() NULL,
        draft = draft
      )
    },
    {
      session$setInputs(
        `r-design_id` = f$design$id,
        `r-baseline` = "temperature",
        `r-added` = "",
        `r-location` = 54,
        `r-intercept_sd` = 10,
        `r-effect_sd` = 20,
        `r-noise_sd` = 3,
        `r-noise_shape` = 3
      )
      chat <- form_session(f$record, list(regression = controller$form_state()))
      id <- chat$session$begin("Prepare the regression.")
      chat$session$tools(id)[[7]]("Prepare the regression.", "Review priors")
      session$setInputs(`r-location` = 60)
      chat$session$finish(id, "Prepared.")
      d <- chat$published$drafts$regression
      draft(d)
      session$flushReact()
      expect_null(controller$prior())
      expect_equal(controller$form_state()$values$location, 60)
      expect_match(controller$status(), "Your edits are kept")
      session$setInputs(`r-use_chat_draft` = 1)
      expect_equal(controller$prior()$spec$settings$location, 54)
      current(NULL)
      session$flushReact()
      expect_null(controller$prior())
      current(f$record)
      session$flushReact()
      controller$restore(d)
      expect_equal(controller$prior()$spec$settings$location, 54)
      expect_null(controller$result())
    }
  )
})
