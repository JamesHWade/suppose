model_fixture <- function(
  id = "demo/tools",
  tools = TRUE,
  text = TRUE,
  price = "0.000001"
) {
  list(
    id = id,
    name = id,
    description = "Synthetic model metadata",
    architecture = list(
      input_modalities = "text",
      output_modalities = if (text) "text" else "image"
    ),
    supported_parameters = if (tools) {
      c("tools", "max_tokens")
    } else {
      "max_tokens"
    },
    pricing = list(prompt = price, completion = "0.000002"),
    context_length = 10000,
    top_provider = list(max_completion_tokens = 8192)
  )
}

test_that("the picker admits text tool models and preserves unknown pricing", {
  x <- inquiry_model_catalog(list(
    model_fixture(),
    model_fixture("demo/no-tools", tools = FALSE),
    model_fixture("demo/image", text = FALSE),
    model_fixture("demo/tools:batch"),
    model_fixture("demo/unknown", price = NULL)
  ))
  expect_named(x, c("demo/tools", "demo/unknown"))
  expect_equal(x[[1]]$input_price, 1)
  expect_equal(x[[1]]$output_price, 2)
  expect_equal(x[[2]]$input_price, NA_real_)
  expect_identical(x[[1]]$max_output, 8192)
})

test_that("switching Deputy models preserves conversation and record", {
  skip_if_not_installed("deputy")
  skip_if_not_installed("shinychat")
  factory <- function(model) {
    suppose_agent(ellmer::chat_openai_compatible(
      base_url = "http://127.0.0.1:1/v1",
      model = model,
      credentials = function() "fixture",
      echo = "none"
    ))
  }
  x <- record_conversation(
    elicitation_record(claim("Fewer meetings might help", "You")),
    list(
      list(
        role = "user",
        text = "Fewer meetings might help",
        status = "complete",
        created_at = now_utc()
      ),
      list(
        role = "assistant",
        text = "What do you mean by help?",
        status = "complete",
        created_at = now_utc()
      )
    )
  )
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(
        input,
        output,
        session,
        initial = x,
        agent_factory = function() factory("demo/first")
      )
    },
    {
      session$flushReact()
      before <- json_data(state$record())
      state$switch_agent(factory("demo/second"))
      expect_identical(state$client()$get_model(), "demo/second")
      expect_identical(json_data(state$record()), before)
      expect_length(state$client()$get_turns(), 2)
      expect_identical(
        ellmer::contents_text(state$client()$get_turns()[[1]]),
        "Fewer meetings might help"
      )
      session$setInputs(
        inquiry_slash_command = list(command = "record", userText = "")
      )
      session$setInputs(
        inquiry_slash_command = list(command = "help", userText = "")
      )
      expect_identical(json_data(state$record()), before)
      expect_length(state$transcript(), 2)
      id <- state$assistant$begin("Clarify this question")
      expect_snapshot(error = TRUE, state$switch_agent(factory("demo/third")))
      expect_identical(state$client()$get_model(), "demo/second")
      state$assistant$cancel()
    }
  )
})

test_that("model changes keep prior proposals and attribute later corrections", {
  x <- elicitation_record(claim("Fewer meetings may help", "You"))
  s <- new_proposal_session(
    function() x,
    model = "demo/first",
    provider = "deputy",
    general = TRUE
  )
  id <- s$begin("Fewer meetings may help")
  tool <- s$tools(id)[[2]]
  tool(
    wording = "Fewer meetings may help",
    source_quote = "Fewer meetings may help",
    reason = "Clarify"
  )
  s$finish(id, "Review this")
  p <- s$pending
  s$set_model("demo/second", "deputy")
  expect_identical(s$pending, p)
  expect_identical(s$pending$context$model, "demo/first")
  id <- s$begin("Our team next quarter")
  s$tools(id)[[2]](
    wording = "Fewer meetings may help our team next quarter",
    source_quote = "Our team next quarter",
    reason = "Add scope",
    scope = "Our team",
    horizon = "Next quarter"
  )
  s$finish(id, "Updated")
  expect_identical(s$pending$context$model, "demo/second")
  expect_identical(s$pending$claim$horizon, "Next quarter")
})

test_that("picker changes are explicit and commands only operate the app", {
  skip_if_not_installed("deputy")
  skip_if_not_installed("shinychat")
  local_mocked_bindings(suppose_muse = function(model, max_tokens) {
    ellmer::chat_openai_compatible(
      base_url = "http://127.0.0.1:1/v1",
      model = model,
      credentials = function() "fixture",
      echo = "none"
    )
  })
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session)
    },
    {
      session$flushReact()
      state$controls$catalog(inquiry_model_catalog(list(model_fixture())))
      session$setInputs(model_choice = "demo/tools", model_max_tokens = 4096)
      expect_null(state$client())
      session$setInputs(choose_model = 1)
      expect_identical(state$client()$get_model(), "demo/tools")
      expect_null(state$record())
      session$setInputs(model_choice = "unlisted/model", choose_model = 2)
      expect_identical(state$client()$get_model(), "demo/tools")
      expect_named(
        state$controls$handlers,
        c(
          "record",
          "test",
          "sensitivity",
          "extend",
          "design",
          "regression",
          "model",
          "tools",
          "help"
        )
      )
      session$setInputs(
        inquiry_slash_command = list(command = "record", userText = "")
      )
      expect_null(state$record())
      expect_length(state$client()$get_turns(), 0)
    }
  )
})

test_that("a catalog failure leaves the current conversation usable", {
  skip_if_not_installed("shinychat")
  local_mocked_bindings(inquiry_catalog_request = function() {
    stop("Offline test")
  })
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session)
    },
    {
      expect_snapshot(session$setInputs(open_models = 1))
      session$flushReact()
      expect_match(output$model_catalog_status, "Could not load the catalog")
      expect_null(state$client())
      session$setInputs(
        inquiry_user_input = "A service might help our customers"
      )
      expect_identical(
        state$record()$revisions[[1]]$claim$wording,
        "A service might help our customers"
      )
    }
  )
})
