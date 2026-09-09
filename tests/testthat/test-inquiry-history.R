test_that("history retains a sealed record and pending suggestion", {
  x <- elicitation_record(claim("The coating may cure faster", "Scientist"))
  state <- new_proposal_session(function() x, general = TRUE)
  id <- state$begin("Help clarify the coating comparison")
  state$tools(id)[[2]](
    "Help clarify the coating comparison",
    "Help clarify the coating comparison",
    "Clarify the comparison",
    target = "Cure time"
  )
  pending <- state$finish(id, "What comparison would be useful?")
  restored <- decode_inquiry_history(encode_inquiry_history(
    x,
    pending,
    state$messages
  ))
  expect_identical(restored$record, x)
  expect_identical(restored$messages, state$messages)
  expect_identical(restored$proposal, pending)
  expect_s3_class(
    apply_assistant_proposal(restored$record, restored$proposal, "Scientist"),
    "suppose_record"
  )
  expect_identical(decode_inquiry_history(NULL)$messages, list())
  expect_error(decode_inquiry_history('{"version":2}'), "Unsupported")
})

test_that("tool failures persist their message without R execution internals", {
  error <- rlang::error_cnd(
    "suppose_source",
    message = "Quote the outcome exactly."
  )
  error$internal <- new.env()
  turn <- list(props = list(error = error, id = "call_1"))
  saved <- history_serializable_turn(turn)
  restored <- jsonlite::unserializeJSON(jsonlite::serializeJSON(saved))
  expect_identical(
    conditionMessage(restored$props$error),
    conditionMessage(error)
  )
  expect_null(restored$props$error$internal)
  expect_identical(restored$props$id, "call_1")
  expect_s3_class(inquiry_history_store(tempdir()), "FileConversationStore")
})

test_that("initial portable conversations open with persistent history enabled", {
  skip_if_not_installed("deputy")
  skip_if_not_installed("shinychat")
  messages <- list(
    list(role = "user", text = "A coating may help"),
    list(role = "assistant", text = "Let us inspect the comparison.")
  )
  messages <- lapply(messages, function(m) {
    m$status <- "completed"
    m$created_at <- now_utc()
    m
  })
  x <- record_conversation(
    elicitation_record(claim("A coating may help", "You")),
    messages
  )
  directory <- tempfile()
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(
        input,
        output,
        session,
        initial = x,
        history_dir = directory,
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
      session$setInputs(inquiry_history_browser_token = "research-loop-test")
      session$flushReact()
      expect_identical(state$record(), x)
      expect_identical(state$transcript(), messages)
      expect_length(state$client()$get_turns(), 2)
      path <- tempfile(fileext = ".json")
      write_record(x, path)
      session$setInputs(inquiry_history_new = 1)
      expect_null(state$record())
      session$setInputs(reopen = list(datapath = path))
      expect_match(state$status(), "record reopened")
      expect_identical(json_data(state$record()), json_data(x))
      expect_length(state$client()$get_turns(), 2)
    }
  )
})
