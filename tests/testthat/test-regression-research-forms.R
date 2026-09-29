research_tool <- function(session, id, name) {
  Filter(function(tool) identical(tool@name, name), session$tools(id))[[1]]
}

research_test_values <- function(f) {
  v <- regression_test_form_defaults(f$before)
  v$planned_csv <- paste(
    capture.output(utils::write.csv(
      f$data[c("observation_id", "condition", "temperature", "duration")],
      row.names = FALSE
    )),
    collapse = "\n"
  )
  v$source <- "future:forms"
  v$protocol <- "independent-v1"
  v$horizon <- "2026-01-03T12:00:00Z"
  v$target <- "Challenge the fixed-time prediction"
  v$design_details <- "Randomized independent preparations"
  v
}

test_that("new regression tools stage portable drafts without committing", {
  skip_if_not_installed("ellmer")
  f <- regression_research_fixture()
  for (form in c("regression_test", "regression_sensitivity")) {
    values <- if (form == "regression_test") {
      research_test_values(f)
    } else {
      v <- regression_sensitivity_form_defaults(f$before)
      v$contrast_csv <- "temperature,duration\n140,60\n160,60"
      v$draws <- 200
      v
    }
    chat <- form_session(f$before)
    request <- paste("Prepare", form, "for review.")
    id <- chat$session$begin(request)
    do.call(
      research_tool(chat$session, id, paste0("draft_", form)),
      c(
        list(source_quote = request, reason = "Review scientific assumptions"),
        values
      )
    )
    expect_length(chat$published$drafts, 0)
    chat$session$finish(id, "Prepared.")
    d <- chat$published$drafts[[form]]
    expect_s3_class(d, "suppose_form_draft")
    history <- decode_inquiry_history(encode_inquiry_history(
      f$before,
      NULL,
      chat$session$messages,
      forms = stats::setNames(list(d), form)
    ))
    expect_identical(json_data(history$forms[[form]]), json_data(d))
    expect_length(history$record$regression_commitments, 0)
    expect_length(history$record$regression_sensitivities, 0)
  }
})

test_that("regression test form protects edits and requires fresh human review", {
  skip_if_no_app()
  f <- regression_research_fixture()
  v <- research_test_values(f)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$before)
      draft <- shiny::reactiveVal(NULL)
      controller <- regression_review_server(
        "r",
        current,
        function() NULL,
        form = "regression_test",
        draft = draft
      )
    },
    {
      for (name in names(v)) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("r-", name))
        )
      }
      chat <- form_session(
        current(),
        list(regression_test = controller$form_state())
      )
      request <- "Use 95 percent predictive coverage."
      id <- chat$session$begin(request)
      research_tool(chat$session, id, "draft_regression_test")(
        request,
        "Inspect coverage",
        coverage = 0.95
      )
      session$setInputs(`r-target` = "My concurrent scientific target")
      chat$session$finish(id, "Prepared.")
      d <- chat$published$drafts$regression_test
      draft(d)
      session$flushReact()
      expect_null(controller$preview())
      expect_identical(
        controller$form_state()$values$target,
        "My concurrent scientific target"
      )
      expect_match(controller$status(), "Manual edits are preserved")
      session$setInputs(`r-use_chat` = 1)
      expect_equal(controller$preview()$fit$prediction$coverage, 0.95)
      # Mock sessions receive update messages but do not echo browser input changes.
      for (name in names(d$values)) {
        do.call(
          session$setInputs,
          stats::setNames(list(d$values[[name]]), paste0("r-", name))
        )
      }
      session$setInputs(`r-reason` = "Review", `r-retain` = 1)
      expect_match(controller$status(), "Confirm your review")
      session$setInputs(
        `r-reviewed` = TRUE,
        `r-independent` = TRUE,
        `r-unseen` = TRUE,
        `r-coverage` = 0.8,
        `r-retain` = 2
      )
      expect_match(controller$status(), "Settings changed")
      session$setInputs(`r-coverage` = 0.95, `r-retain` = 3)
      expect_length(current()$regression_commitments, 1)
      expect_identical(current()$regression_commitments[[1]]$form_draft, d)
      expect_null(controller$preview())
    }
  )
})

test_that("regression sensitivity restoration previews without retaining", {
  skip_if_no_app()
  f <- research_design_fixture()
  v <- regression_sensitivity_form_defaults(f$record)
  v$contrast_csv <- "temperature,duration\n140,60\n160,60"
  v$draws <- 200
  chat <- form_session(f$record)
  request <- "Review regression sensitivity."
  id <- chat$session$begin(request)
  do.call(
    research_tool(chat$session, id, "draft_regression_sensitivity"),
    c(list(source_quote = request, reason = "Assumption check"), v)
  )
  chat$session$finish(id, "Prepared.")
  d <- decode_inquiry_history(encode_inquiry_history(
    f$record,
    NULL,
    chat$session$messages,
    forms = chat$published$drafts
  ))$forms$regression_sensitivity
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      controller <- regression_review_server(
        "s",
        current,
        function() NULL,
        form = "regression_sensitivity"
      )
    },
    {
      controller$restore(d)
      expect_s3_class(
        controller$preview()$fit,
        "suppose_regression_sensitivity"
      )
      expect_length(current()$regression_sensitivities, 0)
      for (name in names(d$values)) {
        value <- d$values[[name]]
        if (name %in% c("powers", "utility_thresholds")) {
          value <- paste(value, collapse = ",")
        }
        do.call(
          session$setInputs,
          stats::setNames(list(value), paste0("s-", name))
        )
      }
      session$setInputs(
        `s-reason` = "Reviewed prior and likelihood assumptions",
        `s-reviewed` = TRUE,
        `s-retain` = 1
      )
      expect_length(current()$regression_sensitivities, 1)
      expect_identical(
        current()$regression_sensitivities[[1]]$form_draft$id,
        d$id
      )
    }
  )
})
