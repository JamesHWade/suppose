test_that("manual workflow requires inspection and recovers from incompatible inputs", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinychat")
  shiny::testServer(
    function(input, output, session) {
      state <- workbench_server(input, output, session, suppose_example())
      current <- state$record
      status <- state$status
      latest <- function() tail(current()$revisions, 1)[[1]]
    },
    {
      c <- latest()$claim
      session$setInputs(
        wording = c$wording,
        scope = c$scope,
        author = c$author,
        threshold = 5,
        reason = "Explore correlation",
        low05 = 45,
        low95 = 55,
        high05 = 51,
        high95 = 65,
        rho = 0,
        sd_low = 3,
        sd_high = 3,
        basis = "Invented",
        seed = 47
      )
      session$setInputs(inspect = 1)
      expect_length(current()$revisions, 4)
      session$setInputs(
        history_revision = "4",
        reviewed = TRUE,
        accept_reason = "Recognizable",
        challenge = "Randomized batches"
      )
      session$setInputs(rho = .8, accept = 1)
      expect_null(latest()$acceptance)
      expect_match(status(), "Inspect the current inputs")
      session$setInputs(low95 = 40, inspect = 2)
      expect_length(current()$revisions, 4)
      expect_match(status(), "Clarify this judgment")
      session$setInputs(low95 = 55, inspect = 3)
      session$setInputs(history_revision = "5", reviewed = TRUE, accept = 2)
      expect_identical(latest()$acceptance$author, c$author)
      expect_length(current()$revisions, 5)
    }
  )
})
test_that("local guidance never pretends to be a model response", {
  expect_match(local_guidance("range", NULL), "5th and 95th")
  expect_match(local_guidance("correlation", NULL), "cannot|do not determine")
  expect_match(local_guidance("evidence", NULL), "randomized")
  expect_match(local_guidance("unrecognized", NULL), "fixed explanations")
})

test_that("downloaded records and uploaded records preserve acceptance", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinychat")
  shiny::testServer(
    function(input, output, session) {
      state <- workbench_server(
        input,
        output,
        session,
        suppose_example(accept = TRUE)
      )
    },
    {
      path <- output$download
      out <- read_record(path)
      expect_identical(out$revisions[[3]]$acceptance$author, "Demo scientist")
      session$setInputs(upload = list(datapath = path))
      expect_identical(json_data(state$record()), json_data(out))
      expect_match(state$status(), "without recomputing")
      bad <- withr::local_tempfile(lines = "broken JSON")
      session$setInputs(upload = list(datapath = bad))
      expect_identical(json_data(state$record()), json_data(out))
    }
  )
})

test_that("completed assistant suggestions require review and reject changed forms", {
  skip_if_not_installed("shinychat")
  skip_if_not_installed("ellmer")
  turn <- shiny::reactiveVal(NULL)
  testthat::local_mocked_bindings(
    chat_server = function(...) {
      list(
        last_turn = turn,
        last_error = function() NULL,
        clear = function() turn(NULL)
      )
    },
    .package = "shinychat"
  )
  client <- new.env()
  client$set_system_prompt <- function(x) NULL
  client$get_model <- function() "fixture-model"
  client$set_tools <- function(x) client$tools <- x
  shiny::testServer(
    function(input, output, session) {
      state <- workbench_server(
        input,
        output,
        session,
        suppose_example(accept = TRUE),
        function() client
      )
    },
    {
      session$setInputs(
        author = "Scientist",
        guide_user_input = "I expect higher strength."
      )
      before <- state$record()
      client$tools[[2]](
        "Higher strength",
        "I expect higher strength.",
        "Clarify"
      )
      expect_null(state$proposal())
      expect_identical(state$record(), before)
      turn(ellmer::Turn("assistant", "Please review the proposal."))
      session$flushReact()
      expect_s3_class(state$proposal(), "suppose_proposal")
      session$setInputs(wording = "Unsaved edit", apply_proposal = 1)
      expect_identical(state$record(), before)
      expect_match(state$status(), "form changed")
      session$setInputs(decline_proposal = 1)
      expect_null(state$proposal())
    }
  )
})
