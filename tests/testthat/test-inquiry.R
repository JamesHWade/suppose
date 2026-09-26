test_that("interpretations span domains without imposing a numerical model", {
  skip_if_not_installed("ellmer")
  for (words in c(
    "Fewer meetings might help our team finish sooner.",
    "Customers might pay for migration help.",
    "Longer exposure might increase variability."
  )) {
    x <- elicitation_record(claim(words, "Scientist"))
    s <- new_proposal_session(function() x, general = TRUE)
    assumption <- "I assume other conditions remain comparable."
    id <- s$begin(paste(words, assumption))
    tools <- s$tools(id)
    tools[[2]](
      words,
      words,
      "Make the question reviewable",
      target = "An observable outcome",
      scope = "The population we are studying",
      expectations = words,
      assumptions = assumption,
      unresolved = "Which outcome should we measure?"
    )
    preview <- jsonlite::fromJSON(tools[[4]]())
    expect_null(preview$summary)
    p <- s$finish(id, "Which outcome matters to you?")
    expect_null(p$candidate)
    expect_null(p$claim$units)
    expect_null(p$claim$threshold)
    expect_identical(p$claim$expectations, words)
    x <- apply_assistant_proposal(x, p, "Scientist")
    x <- accept_interpretation(
      x,
      "Scientist",
      "Matches my intended question",
      "Measure a contrary outcome"
    )
    e <- tail(x$revisions, 1)[[1]]
    expect_identical(e$acceptance$kind, "interpretation")
    expect_null(e$acceptance$prior_id)
    expect_identical(e$acceptance$assistance_id, e$assistance$id)
    x <- record_conversation(x, s$messages)
    path <- withr::local_tempfile(fileext = ".json")
    write_record(x, path)
    expect_identical(json_data(read_record(path)), json_data(x))
    expect_error(
      accept_interpretation(x, "Scientist", "Again", "Contrary outcome"),
      class = "suppose_accepted"
    )
  }
})

test_that("a changed problem cannot inherit an unrelated numerical model", {
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  s <- new_proposal_session(function() x, general = TRUE)
  words <- "I actually want to understand staff retention."
  id <- s$begin(words)
  tools <- s$tools(id)
  tools[[2]](words, words, "Change the question", target = "Staff departures")
  p <- s$finish(id, "Over what period?")
  expect_null(p$claim$units)
  expect_null(p$claim$scope)
  expect_null(p$claim$threshold)
  expect_null(p$candidate)
  expect_null(p$prediction)
  expect_length(p$judgments, 0)
  expect_match(p$preview_issue, "No numerical model")
})

test_that("optional normal modeling uses domain supplied conditions and units", {
  skip_if_not_installed("ellmer")
  x <- elicitation_record(claim(
    "Exposure may change response",
    "Scientist",
    scope = "Controlled future runs"
  ))
  s <- new_proposal_session(function() x, general = TRUE)
  words <- paste(
    "For mean response in mV, central 90% intervals are 10 to 14 at 2 seconds and 14 to 20 at 4 seconds.",
    "Known run SDs are 1 and 2 mV, correlation 0.5, threshold 3 mV. These are invented inputs."
  )
  id <- s$begin(words)
  tools <- s$tools(id)
  tools[[3]](
    2,
    4,
    "seconds",
    "response",
    "mV",
    10,
    14,
    14,
    20,
    .5,
    1,
    2,
    3,
    words,
    "Explicit inputs"
  )
  preview <- jsonlite::fromJSON(tools[[4]]())
  p <- s$finish(id, "Review the model assumptions.")
  expect_true(p$candidate$fit_ok)
  expect_equal(p$candidate$conditions, c(2, 4))
  expect_identical(p$claim$units, "mV")
  expect_match(p$claim$target, "4 seconds.*2 seconds")
  expect_equal(p$prediction$summary$mean_difference$mean, 5)
  expect_identical(preview$prediction_id, p$prediction$id)
  tools <- NULL
  id <- s$begin("Now I want to ask about reliability.")
  tools <- s$tools(id)
  tools[[2]](
    "Reliability",
    "Now I want to ask about reliability.",
    "Different inquiry"
  )
  p <- s$finish(id, "What does reliability mean here?")
  expect_null(p$candidate)
})

test_that("interpretation acceptance is distinct from numerical acceptance", {
  x <- suppose_example()
  x <- accept_interpretation(
    x,
    "Reviewer",
    "I agree with the meaning only",
    "Future measurements"
  )
  a <- tail(x$revisions, 1)[[1]]$acceptance
  expect_null(a$prior_id)
  expect_null(a$prediction_id)
  expect_silent(validate_record(x))
  broken <- x
  broken$revisions[[3]]$acceptance$id <- NULL
  broken$revisions[[3]]$acceptance$prior_id <- broken$revisions[[
    3
  ]]$candidate$id
  broken$revisions[[3]]$acceptance <- seal(
    broken$revisions[[3]]$acceptance,
    "suppose_acceptance"
  )
  expect_error(validate_record(broken), class = "suppose_revision")
})

test_that("Deputy is the chat client and grants only inquiry tools", {
  skip_if_not_installed("deputy")
  client <- ellmer::chat_openai_compatible(
    base_url = "http://127.0.0.1:3893/v1",
    model = "fixture",
    credentials = function() "fixture"
  )
  agent <- suppose_agent(client)
  expect_s3_class(agent, "Agent")
  expect_s3_class(agent, "Chat")
  expect_identical(agent$get_model(), "fixture")
  for (name in c(
    "read_inquiry",
    "propose_interpretation",
    "propose_normal_contrast",
    "preview_proposal"
  )) {
    expect_s7_class(
      deputy::permissions_check(agent$permissions, name, list()),
      deputy::PermissionResultAllow
    )
  }
  for (name in c(
    "r",
    "bash",
    "write_file",
    "accept_revision",
    "apply_assistant_proposal"
  )) {
    expect_s7_class(
      deputy::permissions_check(agent$permissions, name, list()),
      deputy::PermissionResultDeny
    )
  }
})

test_that("shinychat spliced messages enter the Deputy streaming method", {
  skip_if_not_installed("deputy")
  parent <- R6::R6Class(
    "StreamingParent",
    public = list(
      stream_async = function(
        ...,
        tool_mode = "concurrent",
        stream = "text",
        controller = NULL,
        run_context = list(),
        type = NULL
      ) {
        list(
          messages = list(...),
          controller = controller,
          context = run_context,
          stream = stream,
          type = type
        )
      }
    )
  )
  testthat::local_mocked_bindings(Agent = parent, .package = "deputy")
  a <- inquiry_agent_class()$new()
  messages <- list("A question", "A clarification")
  controller <- new.env()
  out <- a$stream_async(
    !!!messages,
    controller = controller,
    stream = "content",
    run_context = list(stage = "inquiry")
  )
  expect_identical(out$messages, messages)
  expect_identical(out$controller, controller)
  expect_identical(out$context, list(stage = "inquiry"))
  expect_identical(out$stream, "content")
  expect_null(out$type)
  typed <- a$stream_async("A question", type = "structured-type")
  expect_identical(typed$messages, list("A question"))
  expect_identical(typed$type, "structured-type")
})

test_that("tool transport uses explicit JSON while receipts retain structured results", {
  skip_if_not_installed("ellmer")
  x <- elicitation_record(claim("Fewer meetings might help", "Ada"))
  state <- new_proposal_session(function() x, general = TRUE)
  id <- state$begin("Read this inquiry")
  response <- state$tools(id)[[1]]()
  expect_s3_class(response, "json")
  decoded <- jsonlite::fromJSON(response)
  expect_identical(decoded$claim$wording, x$revisions[[1]]$claim$wording)
  expect_identical(
    state$request$receipts[[1]]$result$claim$wording,
    decoded$claim$wording
  )
  expect_null(decoded$summary)
})

test_that("a reused cancelled shinychat controller starts a fresh accepted run", {
  skip_if_not_installed("deputy")
  parent <- R6::R6Class(
    "LazyStreamingParent",
    public = list(
      stream_async = function(...) list(stream = "lazy")
    )
  )
  testthat::local_mocked_bindings(Agent = parent, .package = "deputy")
  a <- inquiry_agent_class()$new()
  controller <- ellmer::stream_controller()
  controller$cancel()
  expect_identical(controller$cancelled, TRUE)
  expect_identical(
    a$stream_async("Retry", controller = controller),
    list(stream = "lazy")
  )
  expect_identical(controller$cancelled, FALSE)
})

test_that("a rejected concurrent run does not clear another run's cancellation", {
  skip_if_not_installed("deputy")
  parent <- R6::R6Class(
    "ActiveStreamingParent",
    public = list(
      stream_async = function(...) stop("This agent already has an active run")
    )
  )
  testthat::local_mocked_bindings(Agent = parent, .package = "deputy")
  a <- inquiry_agent_class()$new()
  controller <- ellmer::stream_controller()
  controller$cancel()
  result <- tryCatch(
    a$stream_async("Retry", controller = controller),
    error = identity
  )
  expect_s3_class(result, "error")
  expect_identical(controller$cancelled, TRUE)
})
