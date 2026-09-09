test_that("a hypothetical question cannot be extracted as an expectation", {
  messages <- list(list(
    role = "user",
    text = paste(
      "I have not offered or sold this yet.",
      "If three teams say yes in interviews, would that establish demand?"
    )
  ))
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "three teams say yes in interviews",
      messages,
      "expectations"
    )
  )
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "If three teams say yes in interviews, would that establish demand?",
      messages,
      "expectations"
    )
  )
})

test_that("source checks retain negation and conditions with the message context", {
  words <- paste(
    "This is an invented case.",
    "I do not expect three teams to pay.",
    "If the offer changes, I expect the result to change too."
  )
  messages <- list(list(role = "user", text = words))
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "expect three teams to pay.",
      messages,
      "expectations"
    )
  )
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "I expect the result to change too.",
      messages,
      "expectations"
    )
  )
  statements <- c(
    "I do not expect three teams to pay.",
    "If the offer changes, I expect the result to change too."
  )
  sources <- inquiry_statement_sources(statements, messages, "expectations")
  expect_identical(vapply(sources, `[[`, character(1), "statement"), statements)
  expect_identical(sources[[2]]$source_message, words)
  expect_identical(sources[[2]]$message_index, 1L)
})

test_that("user adoption is distinct from an assistant suggestion", {
  suggestion <- "Coordination quality remains unchanged."
  messages <- list(
    list(role = "assistant", text = suggestion),
    list(role = "user", text = "I am not ready to assume that.")
  )
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(suggestion, messages, "assumptions")
  )
  adopted <- "For this exercise I assume coordination quality remains unchanged."
  messages[[3]] <- list(role = "user", text = adopted)
  sources <- inquiry_statement_sources(adopted, messages, "assumptions")
  expect_identical(sources[[1]]$message_index, 3L)
  expect_identical(sources[[1]]$statement, adopted)
})

test_that("decimal points are not quotation boundaries", {
  messages <- list(list(
    role = "user",
    text = "If the rate exceeds 0.5, I expect fewer completions."
  ))
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "5, I expect fewer completions.",
      messages,
      "expectations"
    )
  )
  expect_snapshot(
    error = TRUE,
    inquiry_statement_sources(
      "If the rate exceeds 0.",
      messages,
      "expectations"
    )
  )
})

test_that("units are not invented by taking letters from ordinary words", {
  messages <- list(list(role = "user", text = "These results were 5mV apart."))
  expect_identical(inquiry_stated_units("mV", messages), "mV")
  expect_snapshot(error = TRUE, inquiry_stated_units("s", messages))
  expect_snapshot(error = TRUE, inquiry_stated_units("m", messages))
})

test_that("missing and malformed tool fields cannot become invented text", {
  expect_null(inquiry_optional_text("null", "units"))
  expect_null(inquiry_optional_text(" NULL ", "scope"))
  expect_null(inquiry_optional_text("unspecified", "units"))
  expect_null(inquiry_optional_text("Not applicable", "units"))
  expect_null(inquiry_optional_text("", "horizon"))
  expect_null(inquiry_optional_text("unspecified fictional horizon", "horizon"))
  expect_null(inquiry_optional_text(
    "not applicable - qualitative fictional test",
    "units"
  ))
  expect_identical(
    inquiry_optional_text("dimensionless", "units"),
    "dimensionless"
  )
  expect_identical(
    inquiry_text_array(list("One", "Two"), "ideas"),
    c("One", "Two")
  )
  expect_identical(inquiry_text_array(list(), "ideas"), character())
  expect_snapshot(
    error = TRUE,
    inquiry_text_array(list(list(text = "Hidden structure")), "ideas")
  )
  expect_snapshot(error = TRUE, inquiry_text_array(list(42), "ideas"))
  expect_snapshot(error = TRUE, inquiry_text_array("null", "expectations"))
})

test_that("invalid interpretation tools are atomic and unknowns clear old fields", {
  skip_if_not_installed("ellmer")
  words <- "If three teams say yes, would that establish demand?"
  x <- elicitation_record(claim(
    "A different question",
    "Reviewer",
    units = "hours",
    scope = "Old scope"
  ))
  s <- new_proposal_session(function() x, general = TRUE)
  id <- s$begin(words)
  tool <- s$tools(id)[[2]]
  before <- s$request$changes
  expect_snapshot(
    error = TRUE,
    tool(words, words, "Clarify", units = "invented units")
  )
  expect_identical(s$request$changes, before)
  expect_snapshot(
    error = TRUE,
    tool(words, words, "Clarify", expectations = "three teams say yes")
  )
  expect_identical(s$request$changes, before)
  expect_snapshot(error = TRUE, tool(words, words, "", target = "Demand"))
  expect_identical(s$request$changes, before)
  tool(
    words,
    words,
    "Keep the conditional question",
    units = "null",
    scope = "null",
    unresolved = words,
    ideas = "Consider offering a small paid review."
  )
  pending <- jsonlite::fromJSON(s$tools(id)[[1]]())
  expect_null(pending$pending_interpretation$units)
  expect_identical(
    pending$ideas_to_consider,
    "Consider offering a small paid review."
  )
  p <- s$finish(id, "An interview yes is not a purchase.")
  expect_null(p$claim$units)
  expect_null(p$claim$scope)
  expect_null(p$claim$expectations)
  expect_null(p$claim$assumptions)
  expect_identical(p$claim$unresolved, words)
  expect_identical(p$changes$ideas, "Consider offering a small paid review.")
  expect_identical(x$revisions[[1]]$claim$units, "hours")
})

test_that("discussion and cancellation preserve an existing proposal identity", {
  skip_if_not_installed("ellmer")
  words <- "I expect the new process to take longer."
  x <- elicitation_record(claim(words, "Reviewer"))
  s <- new_proposal_session(function() x, general = TRUE)
  id <- s$begin(words)
  s$tools(id)[[2]](
    words,
    words,
    "Retain expectation",
    expectations = words,
    ideas = "Compare elapsed time for the same task."
  )
  original <- s$finish(id, "There is a suggestion to review.")
  id <- s$begin("What would elapsed time mean here?")
  expect_identical(
    jsonlite::fromJSON(s$tools(id)[[1]]())$pending_interpretation$expectations,
    words
  )
  unchanged <- s$finish(id, "Time from starting to completing the task.")
  expect_identical(unchanged, original)
  id <- s$begin("I want to ask a different question.")
  s$tools(id)[[2]](
    "A different question",
    "I want to ask a different question.",
    "Change question"
  )
  s$cancel()
  expect_identical(s$pending, original)
  expect_identical(
    s$pending$changes$ideas,
    "Compare elapsed time for the same task."
  )
})

test_that("a tool-only completion can be saved without an invalid empty message", {
  skip_if_not_installed("ellmer")
  words <- "Could this help?"
  x <- elicitation_record(claim(words, "Reviewer"))
  s <- new_proposal_session(function() x, general = TRUE)
  id <- s$begin(words)
  s$tools(id)[[2]](words, words, "Clarify", unresolved = words)
  p <- s$finish(id, "")
  out <- record_conversation(
    apply_assistant_proposal(x, p, "Reviewer"),
    s$messages
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_record(out, path)
  expect_length(read_record(path)$conversation, 1L)
  expect_identical(
    read_record(path)$revisions[[2]]$assistance$proposal$id,
    p$id
  )
})
