test_that("chat stages BED previews with provenance and cancellation protection", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  s <- form_session(f$record)
  request <- "Compare candidate measurements for the temperature contrast."
  id <- s$session$begin(request)
  result <- do.call(
    s$session$tools(id)[[9]],
    c(list(source_quote = request, reason = "Reduce uncertainty"), v)
  )
  expect_match(result, "alloptr")
  expect_length(s$published$drafts, 0)
  s$session$finish(id, "Prepared for review.")
  draft <- s$published$drafts$design
  expect_s3_class(draft, "suppose_form_draft")
  expect_identical(draft$source_quote, request)
  encoded <- encode_inquiry_history(
    f$record,
    NULL,
    s$session$messages,
    forms = list(design = draft)
  )
  decoded <- decode_inquiry_history(encoded)
  expect_identical(json_data(decoded$forms$design), json_data(draft))
  id <- s$session$begin(request)
  do.call(
    s$session$tools(id)[[9]],
    c(list(source_quote = request, reason = "Cancelled change"), v)
  )
  s$session$cancel()
  expect_identical(s$published$drafts$design$id, draft$id)
})

test_that("BED review protects changed settings and requires human confirmation", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      incoming <- shiny::reactiveVal(NULL)
      controller <- research_design_server(
        "d",
        current,
        function() NULL,
        draft = incoming
      )
    },
    {
      for (name in names(v)) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("d-", name))
        )
      }
      session$setInputs(`d-preview` = 1)
      expect_s3_class(controller$preview()$fit, "suppose_research_design")
      session$setInputs(
        `d-choice` = "replicated",
        `d-reason` = "Synthetic pilot planning",
        `d-retain` = 1
      )
      expect_match(controller$status(), "Review the design assumptions")
      expect_length(current()$research_designs, 0)
      session$setInputs(`d-max_units` = 3, `d-reviewed` = TRUE, `d-retain` = 2)
      expect_match(controller$status(), "settings changed")
      session$setInputs(`d-max_units` = 6, `d-retain` = 3)
      expect_length(current()$research_designs, 1)
      expect_null(controller$preview())
      expect_length(current()$commitments, 0)
    }
  )
})

test_that("the complete inquiry host can retain a BED planning choice", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, initial = f$record)
    },
    {
      session$flushReact()
      for (name in names(v)) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("design-", name))
        )
      }
      session$setInputs(`design-preview` = 1)
      session$setInputs(
        `design-choice` = "replicated",
        `design-reviewed` = TRUE,
        `design-reason` = "Reviewed synthetic planning assumptions",
        `design-retain` = 1
      )
      expect_length(state$record()$research_designs, 1)
      expect_identical(
        state$record()$research_designs[[1]]$choice,
        "replicated"
      )
      expect_length(state$record()$commitments, 0)
    }
  )
})
