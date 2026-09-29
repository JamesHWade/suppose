test_that("updates require preview, reject changed inputs, and preserve the prior", {
  skip_if_no_app()
  f <- update_fixture()
  record <- record_observations(f$record, f$obs, reason = "Test observations")
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(record)
      state <- updates_server("learning", current, function() NULL)
    },
    {
      evidence <- record$observations[[1]]$id
      session$setInputs(
        `learning-evidence` = evidence,
        `learning-low` = "low",
        `learning-high` = "high",
        `learning-independent` = TRUE,
        `learning-reason` = "Compare observations"
      )
      session$setInputs(`learning-preview` = 1)
      expect_false(is.null(state$staged()))
      session$setInputs(
        `learning-reason` = "Changed reason",
        `learning-retain` = 1
      )
      expect_match(state$status(), "changed")
      expect_length(current()$updates, 0)
      session$setInputs(`learning-preview` = 2)
      session$setInputs(`learning-retain` = 2)
      expect_length(current()$updates, 1)
      expect_identical(current()$revisions, record$revisions)
      expect_null(state$staged())
    }
  )
})
