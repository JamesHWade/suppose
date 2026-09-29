chat_configuration <- function() {
  ellmer::chat_openai_compatible(
    base_url = "http://127.0.0.1:1/v1",
    model = "fixture/original",
    credentials = function() "fixture",
    echo = "none"
  )
}

test_that("a chat configuration gives isolated sessions without importing history", {
  skip_if_not_installed("ellmer")
  original <- chat_configuration()
  original$set_system_prompt("An unrelated conversation")
  original$set_turns(list(ellmer::Turn("user", "Private earlier message")))
  original$conversation_id <- "earlier-conversation"
  original$register_tool(ellmer::tool(
    function() "Original tool",
    name = "original_tool",
    description = "A tool from the earlier conversation"
  ))
  factory <- inquiry_chat_factory(original)
  first <- factory()
  second <- factory()
  first$set_turns(list(ellmer::Turn("user", "First session only")))
  first$set_model("fixture/changed")
  expect_length(second$get_turns(), 0)
  expect_null(second$get_system_prompt())
  expect_null(second$conversation_id)
  expect_length(second$get_tools(), 0)
  expect_length(original$get_tools(), 1)
  expect_identical(second$get_model(), "fixture/original")
  expect_identical(original$get_model(), "fixture/original")
  expect_identical(original$get_system_prompt(), "An unrelated conversation")
  expect_identical(
    ellmer::contents_text(original$get_turns()[[1]]),
    "Private earlier message"
  )
  original$set_model("fixture/later")
  expect_identical(factory()$get_model(), "fixture/original")
})

test_that("constructors run once per session and retain intentional customization", {
  skip_if_not_installed("ellmer")
  calls <- 0L
  factory <- inquiry_chat_factory(function() {
    calls <<- calls + 1L
    chat_configuration()
  })
  expect_identical(calls, 0L)
  first <- factory()
  second <- factory()
  expect_identical(calls, 2L)
  first$set_model("fixture/changed")
  expect_identical(second$get_model(), "fixture/original")
})

test_that("the public app wires chat objects and constructors into each session", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("shinychat")
  seen <- list()
  local_mocked_bindings(inquiry_server = function(
    input,
    output,
    session,
    initial,
    chat_factory,
    agent_factory,
    history_dir,
    model = NULL
  ) {
    seen[[length(seen) + 1L]] <<- chat_factory()
  })
  original <- chat_configuration()
  for (configuration in list(original, chat_configuration)) {
    app <- suppose_app(chat = configuration, history_dir = NULL)
    shiny::testServer(app, {})
    shiny::testServer(app, {})
  }
  seen[[1]]$set_turns(list(ellmer::Turn("user", "Session one")))
  expect_length(seen, 4L)
  expect_equal(
    vapply(seen[-1], function(x) length(x$get_turns()), integer(1)),
    c(0L, 0L, 0L)
  )
  expect_length(original$get_turns(), 0L)
})

test_that("chat input errors explain valid choices without invoking a provider", {
  skip_if_no_app()
  skip_if_not_installed("ellmer")
  expect_snapshot(error = TRUE, inquiry_chat_factory("model-name"))
  expect_snapshot(error = TRUE, inquiry_chat_factory(function() NULL)())
  expect_snapshot(
    error = TRUE,
    suppose_app(chat = function() NULL, chat_factory = function() NULL)
  )
  expect_snapshot(
    error = TRUE,
    suppose_app(chat = function() NULL, agent_factory = function() NULL)
  )
  expect_snapshot(
    error = TRUE,
    suppose_example_app(chat = function() NULL, chat_factory = function() NULL)
  )
})
