guided_questions <- function() {
  list(
    list(
      question = "What would count as stronger?",
      header = "Measure",
      options = list(
        list(
          label = "Higher average tensile strength",
          description = "Compare batch means."
        ),
        list(
          label = "Fewer weak batches",
          description = "Focus on the lower tail."
        )
      ),
      multiSelect = FALSE
    ),
    list(
      question = "Which conditions matter?",
      header = "Scope",
      options = list(
        list(label = "Formulation F", description = "One formulation."),
        list(label = "All formulations", description = "Every product.")
      ),
      multiSelect = TRUE
    )
  )
}

test_that("guided answers become one quotable user message", {
  text <- inquiry_question_answer_text(
    guided_questions(),
    list(
      list(selected = "Higher average tensile strength", own = ""),
      list(
        selected = c("Formulation F", "All formulations"),
        own = "  mainly the summer line "
      )
    )
  )
  expect_identical(
    text,
    paste(
      "My answers to your questions:",
      "- What would count as stronger? Higher average tensile strength.",
      "- Which conditions matter? Formulation F; All formulations. In my own words: mainly the summer line",
      sep = "\n"
    )
  )
})

test_that("guided answers keep only offered labels and skip blank questions", {
  questions <- guided_questions()
  expect_identical(
    inquiry_question_selection(
      questions[[1]],
      c("Injected", "Fewer weak batches")
    ),
    "Fewer weak batches"
  )
  expect_identical(
    inquiry_question_selection(
      questions[[1]],
      c("Higher average tensile strength", "Fewer weak batches")
    ),
    "Higher average tensile strength"
  )
  expect_identical(
    inquiry_question_answer_text(
      questions,
      list(list(selected = NULL, own = ""), list(selected = "Formulation F"))
    ),
    "My answers to your questions:\n- Which conditions matter? Formulation F."
  )
  expect_null(inquiry_question_answer_text(questions, list()))
})

test_that("a guided question card waits only for the reply that asked it", {
  ask <- list(role = "user", text = "Q", status = "complete")
  reply <- list(role = "assistant", text = "A", status = "complete")
  card <- list(messages = 1L, status = "open")
  expect_match(inquiry_question_card_state(card, list(ask), TRUE), "finishes")
  cancelled <- modifyList(reply, list(status = "cancelled"))
  expect_match(
    inquiry_question_card_state(card, list(ask, cancelled), FALSE),
    "cancelled or failed"
  )
  card$completed <- TRUE
  expect_identical(
    inquiry_question_card_state(card, list(ask, reply), FALSE),
    "ready"
  )
  # A successful reply may consist only of the ask_user call.
  expect_identical(inquiry_question_card_state(card, list(ask), FALSE), "ready")
  expect_match(
    inquiry_question_card_state(card, list(ask, ask), FALSE),
    "moved on"
  )
  expect_match(
    inquiry_question_card_state(card, list(ask, reply, ask), FALSE),
    "moved on"
  )
  card$status <- "answered"
  expect_identical(
    inquiry_question_card_state(card, list(ask, reply), FALSE),
    "answered"
  )
  card$status <- "skipped"
  expect_match(
    inquiry_question_card_state(card, list(ask, reply), FALSE),
    "Skipped"
  )
})

test_that("the question card escapes model-written text", {
  questions <- guided_questions()
  questions[[1]]$options[[1]]$label <- "<script>alert(1)</script>"
  html <- as.character(inquiry_question_card_ui(
    "q",
    list(questions = questions),
    "ready"
  ))
  expect_false(grepl("<script>", html, fixed = TRUE))
  expect_match(html, "Send answers", fixed = TRUE)
})

test_that("guided questions render in chat and send answers as the next message", {
  skip_if_not_installed("shinychat")
  skip_if_not(inquiry_questions_available())
  x <- elicitation_record(claim("Longer cure helps", "You"), "Coating")
  sent <- character()
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, initial = x)
      state$questions <- inquiry_question_cards(
        input,
        output,
        session,
        messages = function() state$assistant$messages,
        running = function() state$assistant$phase == "running",
        submit = function(message) sent <<- c(sent, message)
      )
    },
    {
      id <- state$assistant$begin("Longer cure helps")
      ask <- state$questions$tool(id)[[1]]
      result <- ask(guided_questions())
      expect_s3_class(result, "ellmer::ContentToolResult")
      expect_identical(result@value$status, "deferred")
      expect_error(ask(guided_questions()), "already displayed")
      expect_true(state$questions$waiting(id))
      state$assistant$finish(id, "A few questions first.")
      state$questions$complete(id)
      session$flushReact()
      key <- names(state$questions$entries())
      expect_match(output[[key]]$html, "Send answers", fixed = TRUE)

      inputs <- list(
        "Fewer weak batches",
        "In summer",
        1
      )
      names(inputs) <- paste0(key, c("_q1", "_q2_own", "_send"))
      do.call(session$setInputs, inputs)
      expect_length(sent, 1)
      expect_match(
        sent,
        "What would count as stronger? Fewer weak batches.",
        fixed = TRUE
      )
      expect_match(sent, "In my own words: In summer", fixed = TRUE)
      expect_identical(state$questions$entries()[[key]]$status, "answered")

      restored <- decode_inquiry_history(encode_inquiry_history(
        state$record(),
        state$proposal(),
        state$assistant$messages,
        questions = state$questions$entries()
      ))
      expect_identical(restored$questions, state$questions$entries())
      state$questions$restore(NULL)
      expect_length(state$questions$entries(), 0)
    }
  )
})

test_that("reopening a saved record clears earlier question cards", {
  skip_if_not_installed("shinychat")
  skip_if_not(inquiry_questions_available())
  x <- elicitation_record(claim("Longer cure helps", "You"), "Coating")
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, initial = x)
    },
    {
      path <- output$save
      id <- state$assistant$begin("Longer cure helps")
      state$questions$tool(id)[[1]](guided_questions())
      state$assistant$finish(id, "A few questions first.")
      state$questions$complete(id)
      session$flushReact()
      key <- names(state$questions$entries())
      expect_length(key, 1)
      expect_match(output[[key]]$html, "Send answers", fixed = TRUE)

      session$setInputs(reopen = list(datapath = path))
      expect_match(state$status(), "reopened")
      expect_length(state$questions$entries(), 0)
    }
  )
})
