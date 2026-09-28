test_that("current state is supplied without accumulating stale summaries", {
  x <- suppose_example()
  s <- new_proposal_session(function() x, general = TRUE)
  s$begin("Review the current record")
  first <- inquiry_context_summary(s$request)
  expect_equal(first$revision, 3)
  expect_equal(first$retained_counts[["observations"]], 0)
  prompt <- inquiry_context_prompt(inquiry_prompt(), first)
  next_state <- first
  next_state$revision <- 4L
  next_prompt <- inquiry_context_prompt(prompt, next_state)
  expect_equal(
    length(gregexpr("<suppose-current-state>", next_prompt, fixed = TRUE)[[1]]),
    1
  )
  expect_match(next_prompt, '"revision":4', fixed = TRUE)
  expect_match(
    next_prompt,
    "read_inquiry only when details are missing",
    fixed = TRUE
  )
  expect_match(next_prompt, "Unknown batch SD is not a reason", fixed = TRUE)
})

test_that("validation errors retain useful classes without serializing closure graphs", {
  skip_if_not_installed("ellmer")
  x <- suppose_example()
  s <- new_proposal_session(function() x, general = TRUE)
  id <- s$begin("A complete sentence.")
  e <- tryCatch(
    s$tools(id)[[2]](
      "A proposed wording",
      "Invented quote",
      "Clarify"
    ),
    error = identity
  )
  expect_s3_class(e, "suppose_source")
  expect_lt(length(serialize(e, NULL)), 4096)
  expect_null(e$trace)
})

test_that("agent reconfiguration transfers archived results without transferring tools", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("deputy")
  archive <- withr::local_tempdir()
  from <- suppose_agent(
    ellmer::chat_openai_compatible(
      base_url = "http://127.0.0.1:1/v1",
      model = "fixture",
      credentials = function() "fixture"
    ),
    context_policy = deputy::ContextPolicy(
      max_tool_result_bytes = 100,
      offload_dir = archive
    )
  )
  from$register_tool(ellmer::tool(
    function() paste(rep("evidence", 100), collapse = " "),
    "Fixture",
    name = "large"
  ))
  value <- from$get_tools()[["large"]]()
  expect_match(value, "Tool result offloaded", fixed = TRUE)
  request <- ellmer::ContentToolRequest("req", "large", list())
  from$set_turns(list(
    ellmer::Turn("assistant", list(request)),
    ellmer::Turn(
      "user",
      list(ellmer::ContentToolResult(value, request = request))
    )
  ))
  settings <- from$inquiry_config()
  settings$bundles <- "r"
  to <- from$inquiry_reconfigure(settings)
  on.exit(to$inquiry_close())
  transfer_inquiry_session(from, to)
  expect_identical(to$get_turns(), from$get_turns())
  expect_identical(
    to$resolve_tool_result(value),
    paste(rep("evidence", 100), collapse = " ")
  )
  expect_contains(
    names(to$get_tools()),
    c("run_r_code", "deputy_read_tool_result")
  )
  expect_false("large" %in% names(to$get_tools()))
  expect_match(
    r_text(await_r(to$inquiry_extra_tools()[[1]](code = "1 + 1"))),
    "2"
  )
})
