test_that("bundle grants leave unrelated capabilities denied", {
  skip_if_not_installed("deputy")
  folder <- withr::local_tempdir()
  permissions <- inquiry_permissions(c("files", "write", "web"), folder)
  expect_s7_class(
    deputy::permissions_check(
      permissions,
      "read_file",
      list(path = "input.txt")
    ),
    deputy::PermissionResultAllow
  )
  expect_s7_class(
    deputy::permissions_check(
      permissions,
      "write_file",
      list(path = file.path(folder, "output.txt"))
    ),
    deputy::PermissionResultAllow
  )
  expect_s7_class(
    deputy::permissions_check(
      permissions,
      "write_file",
      list(path = file.path(dirname(folder), "outside.txt"))
    ),
    deputy::PermissionResultDeny
  )
  expect_s7_class(
    deputy::permissions_check(permissions, "run_r_code", list(code = "1+1")),
    deputy::PermissionResultDeny
  )
  expect_s7_class(
    deputy::permissions_check(
      permissions,
      "web_fetch",
      list(url = "https://example.com")
    ),
    deputy::PermissionResultAllow
  )
  expect_s7_class(
    deputy::permissions_check(
      inquiry_permissions(character(), folder),
      "web_fetch",
      list()
    ),
    deputy::PermissionResultDeny
  )
  expect_s7_class(
    deputy::permissions_check(permissions, "propose_interpretation", list()),
    deputy::PermissionResultAllow
  )
  expect_snapshot(error = TRUE, inquiry_extra_tools("unknown"))
})

test_that("tool forms preserve typed arguments and exact source words", {
  skip_if_not_installed("ellmer")
  s <- new_proposal_session(function() NULL, general = TRUE)
  tool <- s$tools(NULL)[[2]]
  args <- inquiry_tool_arguments(
    tool,
    list(
      tool_arg_wording = "A longer cure may help",
      tool_arg_source_quote = "My hunch:\nA longer cure may help",
      tool_arg_reason = "Clarify my hunch",
      tool_arg_expectations = "A longer cure may help\nPreparation remains comparable",
      tool_arg_scope = ""
    )
  )
  expect_length(args$expectations, 2)
  expect_null(args$scope)
  expect_match(
    inquiry_tool_request(tool, args),
    args$source_quote,
    fixed = TRUE
  )
  expect_snapshot(error = TRUE, inquiry_tool_arguments(tool, list()))
  custom <- ellmer::tool(
    function(count, flag = FALSE) NULL,
    "Fixture",
    arguments = list(
      count = ellmer::type_integer("Count"),
      flag = ellmer::type_boolean("Flag", required = FALSE)
    )
  )
  expect_identical(
    inquiry_tool_arguments(
      custom,
      list(tool_arg_count = 3, tool_arg_flag = "false")
    ),
    list(count = 3, flag = FALSE)
  )
  expect_snapshot(
    error = TRUE,
    inquiry_tool_arguments(custom, list(tool_arg_count = 1.5))
  )
  for (tool in c(s$tools(NULL), deputy::tools_all())) {
    expect_s3_class(inquiry_tool_arguments_ui(tool), "shiny.tag.list")
  }
})

test_that("Tools reconfiguration retains the model, record and pending proposal", {
  skip_if_not_installed("deputy")
  skip_if_not_installed("shinychat")
  x <- elicitation_record(claim("The coating may help", "You"))
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(
        input,
        output,
        session,
        initial = x,
        agent_factory = function() {
          suppose_agent(ellmer::chat_openai_compatible(
            base_url = "http://127.0.0.1:1/v1",
            model = "fixture-model",
            credentials = function() "fixture",
            echo = "none"
          ))
        }
      )
    },
    {
      session$flushReact()
      id <- state$assistant$begin("The coating may help")
      state$assistant$tools(id)[[2]](
        "The coating may help",
        "The coating may help",
        "Clarify",
        target = "Coating performance"
      )
      state$assistant$finish(id, "Review this suggestion")
      pending <- state$proposal()
      state$client()$set_turns(list(
        ellmer::Turn("user", "Retain this native context"),
        ellmer::Turn("assistant", "Context retained")
      ))
      before <- state$client()$get_turns()
      session$setInputs(open_tools = 1)
      session$setInputs(
        tools_enable_files = TRUE,
        tools_enable_r = TRUE,
        tools_working_dir = tempdir(),
        tools_max_requests = 4,
        tools_max_calls = 6,
        tools_max_tokens = 12000,
        tools_max_cost = NA_real_,
        tools_context_tokens = 16000,
        tools_compact_to = 0.5,
        tools_result_kib = 32,
        tools_apply = 1
      )
      expect_identical(state$client()$get_model(), "fixture-model")
      expect_identical(state$client()$get_turns(), before)
      expect_identical(state$proposal(), pending)
      expect_identical(state$record(), x)
      expect_identical(state$client()$usage_limits$max_requests, 4L)
      expect_identical(
        state$client()$context_policy$max_tool_result_bytes,
        32768L
      )
      expect_setequal(
        names(state$client()$get_tools()),
        c(
          "read_file",
          "read_markdown",
          "read_csv",
          "list_files",
          "glob_files",
          "grep_files",
          "run_r_code"
        )
      )
      session$setInputs(
        inquiry_slash_command = list(command = "tools", userText = "")
      )
      id <- state$assistant$begin("Hold this response")
      session$setInputs(tools_enable_web = TRUE)
      expect_identical(state$client()$inquiry_config()$bundles, c("files", "r"))
      state$assistant$cancel()
      session$setInputs(tools_enable_files = FALSE)
      expect_identical(state$client()$inquiry_config()$bundles, "r")
      expect_identical(state$client()$get_turns(), before)
    }
  )
})

test_that("activity receipts round trip and older proposal receipts are labeled", {
  old <- list(
    context = list(runs = list(list(run_id = "first"), list(run_id = "second")))
  )
  receipt <- inquiry_saved_activity(NULL, old)
  expect_identical(receipt$run_id, "second")
  expect_identical(receipt$source, "Saved interpretation")
  expect_null(inquiry_saved_activity(NULL))
  restored <- decode_inquiry_history(encode_inquiry_history(
    NULL,
    NULL,
    list(),
    receipt
  ))
  expect_identical(restored$activity, receipt)
})


test_that("every advertised core inquiry tool is permitted", {
  skip_if_not_installed("deputy")
  permissions <- inquiry_permissions(character(), tempdir())
  session <- form_session(suppose_example())$session
  for (tool in session$tools(NULL)) {
    expect_s7_class(
      deputy::permissions_check(permissions, tool@name, list()),
      deputy::PermissionResultAllow
    )
  }
})
