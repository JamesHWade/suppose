test_that("Suppose uses Deputy-owned persistent R tools with fresh rebuilt owners", {
  agent <- fixture_r_agent()
  on.exit(agent$inquiry_close())
  tool <- agent$inquiry_extra_tools()[[1]]
  first <- await_r(tool(code = "x <- 17; plot(1:3); x"))
  expect_match(r_text(first), "17")
  expect_length(
    Filter(function(s) s$type == "plot", first@extra$deputy_r$segments),
    1
  )
  expect_match(r_text(await_r(tool(code = "x + 2"))), "19")
  other <- agent$inquiry_reconfigure(agent$inquiry_config())
  on.exit(other$inquiry_close(), add = TRUE)
  expect_match(
    r_text(await_r(other$inquiry_extra_tools()[[1]](code = "exists('x')"))),
    "FALSE"
  )
  agent$inquiry_close()
  expect_null(agent$inquiry_r_status())
})

test_that("analysis journal survives JSON and does not stale pending proposals", {
  agent <- fixture_r_agent()
  on.exit(agent$inquiry_close())
  result <- await_r(agent$inquiry_extra_tools()[[1]](
    code = "cat('before'); plot(1:3); stop('deliberate')"
  ))
  record <- suppose_example()
  original <- record
  execution <- result@extra$deputy_r
  record <- record_analysis(
    record,
    execution,
    "Inspect a plot",
    "fixture",
    "request1"
  )
  expect_identical(record$revisions, original$revisions)
  expect_identical(proposal_basis_id(record), proposal_basis_id(original))
  expect_length(record$analyses, 1)
  expect_length(
    record_analysis(
      record,
      execution,
      "Inspect a plot",
      "fixture",
      "request1"
    )$analyses,
    1
  )
  path <- tempfile(fileext = ".json")
  write_record(record, path)
  reopened <- read_record(path)
  expect_equal(plain(reopened), plain(record))
  expect_identical(proposal_basis_id(reopened), proposal_basis_id(original))
  html <- as.character(analysis_inventory_ui(reopened)[[1]])
  expect_match(html, "data:image/png;base64,")
  expect_match(html, "deliberate")
  changed <- record_revision(
    record,
    utils::tail(record$revisions, 1)[[1]]$claim,
    reason = "New revision"
  )
  expect_false(identical(proposal_basis_id(changed), proposal_basis_id(record)))
})

test_that("activity receipts preserve S7 run and usage values", {
  result <- deputy::AgentResult(
    response = "Done",
    run_id = "run1",
    usage = deputy::AgentUsage(requests = 2L, tool_calls = 1L)
  )
  agent <- list(last_run = function() result, get_model = function() "fixture")
  receipt <- inquiry_run_activity(agent)
  expect_identical(receipt$run_id, "run1")
  expect_identical(receipt$usage$requests, 2L)
  expect_identical(receipt$usage$tool_calls, 1L)
  expect_identical(receipt$cost_usd, 0)
})

test_that("conversation restoration resets runtime outside a reactive consumer", {
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(
        input,
        output,
        session,
        agent_factory = fixture_r_agent
      )
    },
    {
      before <- state$client()
      reset_done <- FALSE
      session$onFlushed(
        function() {
          state$reset_runtime()
          reset_done <<- TRUE
        },
        once = TRUE
      )
      session$flushReact()
      expect_true(reset_done)
      expect_false(identical(state$client(), before))
      expect_null(before$inquiry_r_status())
      expect_false(identical(
        state$client()$inquiry_config()$conversation_id,
        before$inquiry_config()$conversation_id
      ))
    }
  )
})

test_that("an analysis arriving during a proposal preserves reviewability", {
  words <- "Longer exposure may change the response."
  x <- elicitation_record(claim(words, "Analyst"))
  s <- new_proposal_session(function() x, general = TRUE)
  id <- s$begin(words)
  tools <- s$tools(id)
  tools[[2]](words, words, "Clarify the target", target = "Measured response")
  execution <- list(
    schema_version = 1L,
    code = "1 + 1",
    session_id = "r1",
    execution_id = "e1",
    generation = 1L,
    fresh = TRUE,
    reset_reason = NULL,
    outcome = "complete",
    segments = list(list(type = "text", text = "2"))
  )
  x <- record_analysis(x, execution, words, "fixture", id)
  p <- s$finish(id, "Review this interpretation.")
  applied <- apply_assistant_proposal(x, p, "Analyst")
  expect_length(applied$revisions, 2)
  expect_identical(applied$analyses, x$analyses)
  expect_error(
    apply_assistant_proposal(applied, p, "Analyst"),
    class = "suppose_stale"
  )
})
