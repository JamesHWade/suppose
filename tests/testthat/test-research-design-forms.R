test_that("chat stages BED previews with provenance and cancellation protection", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  s <- form_session(f$record)
  request <- "Compare candidate measurements for the temperature contrast."
  id <- s$session$begin(request)
  result <- do.call(
    s$session$tools(id)[[9]],
    c(list(source_quote = request, reason = "Reduce uncertainty"), v)
  )
  expect_match(result, "alloptr")
  expect_length(s$published$drafts, 0)
  s$session$finish(id, "Prepared for review.")
  draft <- s$published$drafts$design
  expect_s3_class(draft, "suppose_form_draft")
  expect_identical(draft$source_quote, request)
  encoded <- encode_inquiry_history(
    f$record,
    NULL,
    s$session$messages,
    forms = list(design = draft)
  )
  decoded <- decode_inquiry_history(encoded)
  expect_identical(json_data(decoded$forms$design), json_data(draft))
  id <- s$session$begin(request)
  do.call(
    s$session$tools(id)[[9]],
    c(list(source_quote = request, reason = "Cancelled change"), v)
  )
  s$session$cancel()
  expect_identical(s$published$drafts$design$id, draft$id)
})

test_that("BED review protects changed settings and requires human confirmation", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(f$record)
      incoming <- shiny::reactiveVal(NULL)
      controller <- research_design_server(
        "d",
        current,
        function() NULL,
        draft = incoming
      )
    },
    {
      for (name in names(v)) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("d-", name))
        )
      }
      session$setInputs(`d-preview` = 1)
      expect_s3_class(controller$preview()$fit, "suppose_research_design")
      session$setInputs(
        `d-choice` = "replicated",
        `d-reason` = "Synthetic pilot planning",
        `d-retain` = 1
      )
      expect_match(controller$status(), "Review the design assumptions")
      expect_length(current()$research_designs, 0)
      session$setInputs(`d-max_units` = 3, `d-reviewed` = TRUE, `d-retain` = 2)
      expect_match(controller$status(), "settings changed")
      session$setInputs(`d-max_units` = 6, `d-retain` = 3)
      expect_length(current()$research_designs, 1)
      expect_null(controller$preview())
      expect_length(current()$commitments, 0)
    }
  )
})

test_that("the complete inquiry host can retain a BED planning choice", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  v <- research_design_test_values(f)
  shiny::testServer(
    function(input, output, session) {
      state <- inquiry_server(input, output, session, initial = f$record)
    },
    {
      session$flushReact()
      for (name in names(v)) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("design-", name))
        )
      }
      session$setInputs(`design-preview` = 1)
      session$setInputs(
        `design-choice` = "replicated",
        `design-reviewed` = TRUE,
        `design-reason` = "Reviewed synthetic planning assumptions",
        `design-retain` = 1
      )
      expect_length(state$record()$research_designs, 1)
      expect_identical(
        state$record()$research_designs[[1]]$choice,
        "replicated"
      )
      expect_length(state$record()$commitments, 0)
    }
  )
})

test_that("resuming a reviewed plan restores actual settings and retains ancestry", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  original <- research_design_test_preview(f)
  x <- record_research_design(
    f$record,
    original,
    "replicated",
    "Reviewer",
    "Original plan",
    TRUE
  )
  first <- x$research_designs[[1]]
  settings <- research_design_settings(x, first$id)
  expect_equal(settings$candidates, f$candidates)
  expect_equal(settings$contrast, f$contrast)
  expect_identical(settings$source_plan_id, first$id)
  settings$candidates$cost[
    settings$candidates$candidate_id == "replicated"
  ] <- 0.1
  changed <- do.call(design_regression, c(list(x = x), settings))
  x <- record_research_design(
    x,
    changed,
    "replicated",
    "Reviewer",
    "Revised experiment cost",
    TRUE
  )
  expect_identical(x$research_designs[[1]], first)
  expect_identical(x$research_designs[[2]]$design$source_plan_id, first$id)
  path <- tempfile()
  write_record(x, path)
  expect_equal(
    research_design_settings(read_record(path), first$id),
    research_design_settings(x, first$id)
  )
})

test_that("a cost-only chat revision preserves the resumed plan and concurrent edits", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  x <- record_research_design(
    f$record,
    research_design_test_preview(f),
    "replicated",
    "Reviewer",
    "Original research plan",
    TRUE
  )
  path <- tempfile()
  write_record(x, path)
  x <- read_record(path)
  first <- x$research_designs[[1]]
  v <- research_plan_form_values(x, first$id)
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(x)
      draft <- shiny::reactiveVal(NULL)
      controller <- research_design_server("d", current, function() NULL, draft)
    },
    {
      session$setInputs(`d-plan_id` = first$id, `d-resume_plan` = 1)
      expect_null(controller$preview())
      expect_identical(controller$form_state()$values$source_plan_id, first$id)
      for (name in setdiff(names(v), "source_plan_id")) {
        do.call(
          session$setInputs,
          stats::setNames(list(v[[name]]), paste0("d-", name))
        )
      }
      chat <- form_session(current(), list(design = controller$form_state()))
      request <- "Change only the replicated experiment cost to 0.1."
      costs <- f$candidates
      costs$cost[costs$candidate_id == "replicated"] <- 0.1
      csv <- paste(
        capture.output(utils::write.csv(costs, row.names = FALSE)),
        collapse = "\n"
      )
      id <- chat$session$begin(request)
      chat$session$tools(id)[[9]](
        request,
        "Updated cost assumption",
        candidates_csv = csv
      )
      session$setInputs(`d-max_units` = 4)
      chat$session$finish(id, "Prepared cost comparison.")
      d <- chat$published$drafts$design
      expect_equal(
        d$values[setdiff(names(v), "candidates_csv")],
        v[setdiff(names(v), "candidates_csv")]
      )
      draft(d)
      session$flushReact()
      expect_null(controller$preview())
      expect_equal(controller$form_state()$values$max_units, 4)
      expect_match(controller$status(), "form edits are preserved")
      session$setInputs(`d-use_chat` = 1)
      expect_identical(controller$preview()$fit$source_plan_id, first$id)
      for (name in setdiff(names(d$values), "source_plan_id")) {
        do.call(
          session$setInputs,
          stats::setNames(list(d$values[[name]]), paste0("d-", name))
        )
      }
      session$setInputs(
        `d-choice` = "replicated",
        `d-reviewed` = TRUE,
        `d-reason` = "Revised only cost",
        `d-retain` = 1
      )
      expect_length(current()$research_designs, 2)
      expect_identical(current()$research_designs[[1]], first)
      expect_identical(
        current()$research_designs[[2]]$design$source_plan_id,
        first$id
      )
      expect_equal(
        current()$research_designs[[2]]$design$candidates[[4]]$cost,
        0.1
      )
    }
  )
})

test_that("resuming protects populated forms and rejects a revised scientific claim", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  x <- record_research_design(
    f$record,
    research_design_test_preview(f),
    "replicated",
    "Reviewer",
    "Original plan",
    TRUE
  )
  id <- x$research_designs[[1]]$id
  shiny::testServer(
    function(input, output, session) {
      current <- shiny::reactiveVal(x)
      controller <- research_design_server("d", current, function() NULL)
    },
    {
      session$setInputs(
        `d-candidates_csv` = "Manual candidate draft",
        `d-plan_id` = id,
        `d-resume_plan` = 1
      )
      expect_identical(
        controller$form_state()$values$candidates_csv,
        "Manual candidate draft"
      )
      expect_null(controller$form_state()$values$source_plan_id)
      expect_match(controller$status(), "Current form edits are preserved")
      session$setInputs(`d-replace_plan` = 1)
      expect_identical(controller$form_state()$values$source_plan_id, id)
    }
  )
  claim <- revise_claim(
    tail(x$revisions, 1)[[1]]$claim,
    "Reviewer",
    "Revise target",
    scope = "A new scientific scope"
  )
  x <- record_revision(x, claim, reason = "New scope")
  expect_snapshot(error = TRUE, research_design_settings(x, id))
})
