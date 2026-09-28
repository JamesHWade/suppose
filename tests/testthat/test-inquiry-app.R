test_that("local chat starts empty and saves a non-laboratory interpretation", {
  skip_if_not_installed("shinychat")
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session)
    },
    {
      expect_null(state$record())
      words <- "Fewer meetings might help our team finish work sooner."
      session$setInputs(author = "You", inquiry_user_input = words)
      expect_identical(state$record()$revisions[[1]]$claim$wording, words)
      expect_null(state$record()$revisions[[1]]$candidate)
      expect_length(state$transcript(), 2)
      session$setInputs(
        wording = words,
        target = "Time to finish work",
        scope = "Our team",
        horizon = "Next quarter",
        expectations = "Less coordination overhead",
        assumptions = "Coordination stays effective",
        unresolved = "Which meetings help?",
        edit_reason = "Define the question",
        retain = 1
      )
      expect_length(state$record()$revisions, 2)
      session$setInputs(
        revision = "2",
        reviewed = TRUE,
        review_reason = "This expresses my question",
        challenge = "Work takes longer",
        accept = 1
      )
      e <- tail(state$record()$revisions, 1)[[1]]
      expect_identical(e$acceptance$kind, "interpretation")
      path <- output$save
      saved <- read_record(path)
      expect_length(saved$conversation, 2)
      expect_identical(saved$revisions[[2]]$claim$target, "Time to finish work")
      session$setInputs(reopen = list(datapath = path))
      expect_identical(json_data(state$record()), json_data(saved))
      expect_length(state$transcript(), 2)
      expect_match(state$status(), "reopened")
      expect_match(output$reopen_status, "reopened")
    }
  )
})

test_that("unsaved editor changes cannot be mistaken for accepted meaning", {
  skip_if_not_installed("shinychat")
  x <- elicitation_record(claim("A service might help", "You"))
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(
        author = "You",
        wording = "A different service",
        reviewed = TRUE,
        review_reason = "Useful",
        challenge = "No demand",
        accept = 1
      )
      expect_null(state$record()$revisions[[1]]$acceptance)
      expect_match(state$status(), "Retain your editor changes")
    }
  )
})

test_that("pending suggestions require resolution and corrected application retains provenance", {
  skip_if_not_installed("shinychat")
  skip_if_not_installed("ellmer")
  words <- "If three teams say yes, would that establish demand?"
  x <- elicitation_record(claim(words, "Reviewer"))
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(
        author = "Reviewer",
        wording = words,
        reviewed = TRUE,
        review_reason = "I reviewed it",
        challenge = "No one pays"
      )
      id <- state$assistant$begin(words)
      state$assistant$tools(id)[[2]](
        words,
        words,
        "Keep the open question",
        unresolved = words,
        ideas = "Offer a paid review as a small trial."
      )
      original <- state$assistant$finish(
        id,
        "An interview yes is not a purchase."
      )
      session$flushReact()
      session$setInputs(accept = 1)
      expect_null(state$record()$revisions[[1]]$acceptance)
      expect_match(state$status(), "pending suggestion")
      session$setInputs(edit_proposal = 1)
      session$setInputs(
        correct_wording = "Would an interview yes predict a paid review?",
        correct_target = "Paid review commitment",
        correct_scope = "Three fictional teams",
        correct_horizon = "Next week",
        correct_units = "",
        correct_expectations = "",
        correct_assumptions = "",
        correct_unresolved = words,
        correction_reason = "Narrow the target to a paid review",
        apply_correction = 1
      )
      expect_null(state$proposal())
      e <- tail(state$record()$revisions, 1)[[1]]
      expect_identical(e$claim$target, "Paid review commitment")
      expect_null(e$acceptance)
      expect_identical(e$assistance$proposal, original)
      expect_identical(
        e$assistance$correction_reason,
        "Narrow the target to a paid review"
      )
      session$setInputs(
        wording = e$claim$wording,
        target = e$claim$target,
        scope = e$claim$scope,
        horizon = e$claim$horizon,
        unresolved = words,
        revision = "2",
        reviewed = TRUE,
        accept = 2
      )
      expect_identical(
        tail(state$record()$revisions, 1)[[1]]$acceptance$kind,
        "interpretation"
      )
      saved <- read_record(output$save)
      expect_identical(saved$revisions[[2]]$assistance$proposal$id, original$id)
      expect_identical(
        saved$revisions[[2]]$assistance$corrections$target,
        "Paid review commitment"
      )
    }
  )
})

test_that("a correction editor cannot apply a replaced or declined suggestion", {
  skip_if_not_installed("shinychat")
  skip_if_not_installed("ellmer")
  words <- "Would a review help?"
  x <- elicitation_record(claim(words, "Reviewer"))
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(author = "Reviewer", wording = words)
      id <- state$assistant$begin(words)
      state$assistant$tools(id)[[2]](words, words, "Clarify")
      state$assistant$finish(id, "Consider a small review.")
      session$flushReact()
      session$setInputs(edit_proposal = 1)
      state$assistant$clear_proposal()
      session$setInputs(apply_correction = 1)
      expect_match(state$status(), "suggestion changed")
      expect_identical(state$record(), x)
    }
  )
})

test_that("the inquiry host binds expectation projections and model relationships", {
  skip_if_no_app()
  x <- suppose_example(accept = TRUE)
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(`expectation_check-linear` = TRUE)
      expect_match(
        output[["expectation_check-comparison"]]$html,
        "assumed extrapolation"
      )
      session$setInputs(
        author = "Reviewer",
        `model_reference-model` = x$revisions[[2]]$candidate$id,
        `model_reference-claim` = "new",
        `model_reference-wording` = "A separate claim",
        `model_reference-reason` = "Implications only",
        `model_reference-retain` = 1
      )
      expect_length(state$record()$model_references, 1)
      expect_identical(state$record()$revisions, x$revisions)
      session$setInputs(`model_reference-retain` = 2)
      expect_length(state$record()$model_references, 1)
      expect_match(output[["model_reference-status"]]$html, "just retained")
    }
  )
})

test_that("failed uploads explain recovery beside the upload without losing the record", {
  skip_if_no_app()
  x <- elicitation_record(claim("A draft", "You"))
  bad <- withr::local_tempfile(fileext = ".json")
  writeLines("not JSON", bad)
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, x)
    },
    {
      session$setInputs(reopen = list(datapath = bad))
      expect_identical(state$record(), x)
      expect_identical(output$reopen_status, state$status())
      expect_gt(nchar(output$reopen_status), 0)
    }
  )
})
