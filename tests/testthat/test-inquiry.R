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
  skip_if_no_deputy()
  client <- ellmer::chat_openai_compatible(
    base_url = "http://127.0.0.1:3893/v1",
    model = "fixture",
    credentials = function() "fixture"
  )
  agent <- suppose_agent(client)
  expect_s3_class(agent, "Agent")
  expect_s3_class(agent, "Chat")
  expect_identical(agent$get_model(), "fixture")
  tools <- form_session(suppose_example())$session$tools(NULL)
  names(tools) <- vapply(tools, function(tool) tool@name, character(1))
  for (name in c(
    "read_inquiry",
    "propose_interpretation",
    "propose_normal_contrast",
    "preview_proposal"
  )) {
    # Deputy checks each call against the tool's own annotations.
    expect_s7_class(
      deputy::permissions_check(
        agent$permissions,
        name,
        list(),
        context = list(tool_annotations = tools[[name]]@annotations)
      ),
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

test_that("a Deputy turn stages an interpretation through the inquiry tools", {
  skip_if_no_deputy()
  skip_on_cran()
  words <- "I think fewer meetings would help our team finish work sooner."
  wording <- "Fewer recurring meetings may reduce the time our team takes to finish work."
  url <- local_scripted_provider(
    "propose_interpretation",
    list(wording = wording, source_quote = words, reason = "Scripted review")
  )
  record <- elicitation_record(claim(words, "Researcher"), "Meetings")
  proposal <- NULL
  session <- new_proposal_session(
    function() record,
    function(p) proposal <<- p,
    general = TRUE
  )
  agent <- suppose_agent(ellmer::chat_openai_compatible(
    base_url = url,
    model = "fixture",
    credentials = function() "fixture",
    echo = "none"
  ))
  id <- session$begin(words)
  agent$set_tools(c(session$tools(id), agent$inquiry_extra_tools()))
  agent$run_sync(words)
  session$finish(id, "Scripted reply.")
  expect_s3_class(proposal, "suppose_proposal")
  expect_identical(proposal$claim$wording, wording)
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
