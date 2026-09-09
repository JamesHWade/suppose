test_that("inline decisions apply only their own completed draft and survive history", {
  skip_if_not_installed("shinychat")
  x <- elicitation_record(claim("The coating may help", "You"), "Coating")
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, initial = x)
    },
    {
      session$setInputs(wording = "The coating may help")
      session$flushReact()
      make_draft <- function(wording = "The coating may help") {
        id <- state$assistant$begin("The coating may help")
        result <- state$assistant$tools(id)[[2]](
          wording,
          "The coating may help",
          "Clarify",
          target = "Coating performance"
        )
        state$assistant$finish(id, "Please review this draft.")
        session$flushReact()
        list(
          id = id,
          result = result,
          key = tail(names(state$cards$entries()), 1)
        )
      }
      first <- make_draft()
      expect_s3_class(first$result, "ellmer::ContentToolResult")
      expect_match(first$result@value, "Interpretation proposed", fixed = TRUE)
      expect_match(
        as.character(first$result@extra$display$html),
        first$key,
        fixed = TRUE
      )
      expect_match(
        output[[first$key]]$html,
        "Apply interpretation",
        fixed = TRUE
      )
      encoded <- encode_inquiry_history(
        state$record(),
        state$proposal(),
        state$assistant$messages,
        cards = state$cards$entries()
      )
      restored <- decode_inquiry_history(encoded)
      expect_identical(restored$cards, state$cards$entries())
      state$cards$restore(restored$cards)
      expect_match(
        output[[first$key]]$html,
        "Apply interpretation",
        fixed = TRUE
      )
      newer <- make_draft("The coating could improve performance")
      do.call(session$setInputs, setNames(list(1), paste0(first$key, "_apply")))
      expect_identical(state$record(), x)
      expect_identical(state$proposal()$context$request_id, newer$id)
      do.call(session$setInputs, setNames(list(1), paste0(newer$key, "_apply")))
      expect_length(state$record()$revisions, 2)
      expect_null(state$proposal())
      expect_null(tail(state$record()$revisions, 1)[[1]]$acceptance)
      expect_match(
        output[[newer$key]]$html,
        "Applied as revision 2",
        fixed = TRUE
      )
      do.call(session$setInputs, setNames(list(2), paste0(newer$key, "_apply")))
      expect_length(state$record()$revisions, 2)
      declined <- make_draft()
      do.call(
        session$setInputs,
        setNames(list(1), paste0(declined$key, "_decline"))
      )
      expect_null(state$proposal())
      expect_match(output[[declined$key]]$html, "Declined", fixed = TRUE)
      expect_length(state$record()$revisions, 2)
      state$cards$restore(NULL)
      do.call(
        session$setInputs,
        setNames(list(2), paste0(declined$key, "_apply"))
      )
      expect_length(state$record()$revisions, 2)
    }
  )
})

test_that("native suggestion markup is included in the model instructions", {
  expect_match(
    inquiry_prompt(),
    '<span class="suggestion submit"',
    fixed = TRUE
  )
  expect_match(inquiry_prompt(), "Omit suggestions", fixed = TRUE)
})
