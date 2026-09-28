test_that("a chat tool fills controls, prepares a preview, and preserves later manual edits", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(x)
      incoming <- shiny::reactiveVal(NULL)
      controller <- extension_server(
        "e",
        current,
        function() NULL,
        draft = incoming
      )
    },
    {
      session$setInputs(
        `e-predictor` = "Added predictor",
        `e-predictor_units` = "units",
        `e-center` = 0,
        `e-scale` = 1,
        `e-effect_mean` = 0,
        `e-effect_sd` = "",
        `e-plausible_lower` = "",
        `e-plausible_upper` = "",
        `e-reason` = "Consider an extension"
      )
      f <- form_session(x, list(extension = controller$form_state()))
      id <- f$session$begin(
        "Add duration centered at 60 with a change of 10 minutes."
      )
      f$session$tools(id)[[5]](
        "Duration",
        "Add duration centered at 60 with a change of 10 minutes.",
        "Duration may affect strength",
        predictor_units = "minutes",
        center = 60,
        scale = 10
      )
      f$session$finish(id, "Prepared.")
      d <- f$published$drafts$extension
      incoming(d)
      session$flushReact()
      expect_s3_class(
        controller$staged()$comparison,
        "suppose_extension_comparison"
      )
      expect_equal(controller$staged()$args$center, 60)
      expect_length(current()$model_extensions, 0)
      # Mirror the browser acknowledgement of updateInput messages.
      session$setInputs(
        `e-predictor` = "Duration",
        `e-predictor_units` = "minutes",
        `e-center` = 60,
        `e-scale` = 10,
        `e-reason` = d$reason
      )
      session$setInputs(`e-retain` = 1)
      expect_length(current()$model_extensions, 1)
      expect_identical(current()$model_extensions[[1]]$form_draft, d)
      expect_null(controller$staged())
    }
  )
})

test_that("newer form edits require an explicit choice before chat replaces them", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(x)
      incoming <- shiny::reactiveVal(NULL)
      controller <- extension_server(
        "e",
        current,
        function() NULL,
        draft = incoming
      )
    },
    {
      session$setInputs(
        `e-predictor` = "Duration",
        `e-predictor_units` = "minutes",
        `e-center` = 60,
        `e-scale` = 10,
        `e-effect_mean` = 0,
        `e-effect_sd` = "",
        `e-plausible_lower` = "",
        `e-plausible_upper` = "",
        `e-reason` = "Consider duration"
      )
      f <- form_session(x, list(extension = controller$form_state()))
      id <- f$session$begin("Set duration effect SD to 2.")
      f$session$tools(id)[[5]](
        "Duration",
        "Set duration effect SD to 2.",
        "Review spread",
        effect_sd = 2
      )
      session$setInputs(`e-center` = 70)
      f$session$finish(id, "Prepared.")
      incoming(f$published$drafts$extension)
      session$flushReact()
      expect_null(controller$staged())
      expect_match(controller$status(), "Your edits are kept")
      expect_equal(controller$form_state()$values$center, 70)
      session$setInputs(`e-use_chat_draft` = 1)
      expect_equal(controller$staged()$args$center, 60)
      expect_equal(controller$staged()$args$effect_sd, 2)
      current(NULL)
      session$flushReact()
      expect_null(controller$staged())
      expect_null(controller$source())
      current(x)
      session$flushReact()
      controller$restore(f$published$drafts$extension)
      expect_equal(controller$staged()$args$center, 60)
      expect_equal(controller$staged()$args$effect_sd, 2)
      expect_null(controller$incoming())
    }
  )
})
