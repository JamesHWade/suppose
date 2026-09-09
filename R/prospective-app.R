prospective_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("A future test"),
    shiny::tags$p(
      "Freeze what you expect before examining new outcomes. Later assessments keep the original prediction and any inconclusive results."
    ),
    shiny::uiOutput(ns("retained")),
    shiny::tags$details(
      shiny::tags$summary("Plan and freeze a prediction"),
      shiny::uiOutput(ns("basis")),
      shiny::textInput(ns("source"), "Identifier for the future dataset"),
      shiny::textInput(ns("protocol"), "Collection protocol identifier"),
      shiny::selectInput(
        ns("design"),
        "Kind of test",
        c(
          "Future observational comparison" = "observational",
          "Planned intervention" = "intervention"
        )
      ),
      shiny::textAreaInput(
        ns("design_details"),
        "How will sampling or assignment work? What limits the interpretation?",
        width = "100%"
      ),
      shiny::dateInput(
        ns("deadline_date"),
        "Collect outcomes by",
        value = Sys.Date() + 7
      ),
      shiny::textInput(
        ns("deadline_time"),
        "Deadline time (UTC, hh:mm:ss)",
        "23:59:59"
      ),
      shiny::numericInput(
        ns("coverage"),
        "Central predictive probability (%)",
        90,
        min = 0.1,
        max = 99.9
      ),
      shiny::textInput(ns("author"), "Person making the commitment"),
      shiny::textInput(ns("reason"), "Why would this test be informative?"),
      shiny::checkboxInput(
        ns("independent"),
        "The planned measurements are independent units",
        FALSE
      ),
      shiny::checkboxInput(
        ns("unseen"),
        "I have not examined the designated outcomes",
        FALSE
      ),
      shiny::tags$p(
        "These declarations and a timestamp do not independently establish lack of exposure or a valid design. The first rule requires every planned measurement, the same units and protocol, and no unit conversion."
      ),
      shiny::actionButton(ns("preview"), "Preview the test commitment"),
      shiny::uiOutput(ns("commit_preview"))
    ),
    shiny::tags$details(
      shiny::tags$summary("Assess a frozen prediction"),
      shiny::uiOutput(ns("selection")),
      shiny::uiOutput(ns("selected")),
      shiny::downloadButton(
        ns("template"),
        "Download planned measurements CSV"
      ),
      shiny::actionButton(ns("prepare_import"), "Prepare measurement import"),
      shiny::tags$p(
        "Fill actual outcomes, unit identities and UTC measurement times in the CSV, then attach it under Measured observations. The assessment uses every planned ID from the committed source, including data attached after a claim revision."
      ),
      shiny::textInput(ns("assessor"), "Person reviewing the outcomes"),
      shiny::textInput(ns("assessment_reason"), "Why record this assessment?"),
      shiny::checkboxInput(
        ns("protocol_followed"),
        "I reviewed collection and confirm the committed protocol was followed",
        FALSE
      ),
      shiny::actionButton(ns("preview_assessment"), "Preview the assessment"),
      shiny::uiOutput(ns("assessment_preview"))
    ),
    shiny::tags$div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    )
  )
}

commitment_details_ui <- function(c, record, draft = FALSE) {
  shiny::tagList(
    inquiry_field(
      "Original claim",
      record$revisions[[c$revision]]$claim$wording
    ),
    shiny::tags$p(test_prediction_text(c)),
    inquiry_field(
      "Prediction basis",
      if (is.null(c$update_id)) {
        paste("Prior in revision", c$revision)
      } else {
        paste(
          "Retained update",
          substr(c$update_id, 1, 12),
          "of revision",
          c$revision
        )
      }
    ),
    inquiry_field("Deadline (UTC)", c$horizon),
    if (draft) {
      shiny::tags$p(
        "The collection window starts when you freeze this prediction."
      )
    } else {
      inquiry_field("Frozen at (UTC)", c$created_at)
    },
    inquiry_field("Source", c$source),
    inquiry_field("Protocol", c$protocol),
    inquiry_field("Design", c$design),
    inquiry_field("Sampling or assignment", c$design_details),
    inquiry_field("Reason", c$reason),
    shiny::tags$p(
      "Compare the second sample mean minus the first with the inclusive frozen interval only after every planned measurement is available. Missing outcomes are not imputed. An incomplete set is waiting before the deadline and inconclusive afterward."
    ),
    if (!is.null(c$replaces)) inquiry_field("Revises commitment", c$replaces),
    shiny::tags$details(
      shiny::tags$summary(paste("Planned measurements:", length(c$planned))),
      shiny::tags$table(
        class = "table table-sm",
        shiny::tags$caption(
          "First 20 planned IDs; the complete plan is retained and available as a CSV."
        ),
        shiny::tags$thead(shiny::tags$tr(
          shiny::tags$th("ID"),
          shiny::tags$th("Condition")
        )),
        shiny::tags$tbody(lapply(utils::head(c$planned, 20), function(row) {
          shiny::tags$tr(
            shiny::tags$td(row$observation_id),
            shiny::tags$td(row$condition)
          )
        }))
      )
    ),
    shiny::tags$details(
      shiny::tags$summary("Exact references"),
      inquiry_field("Commitment", c$id),
      inquiry_field("Claim", c$claim_id),
      inquiry_field("Prior", c$prior_id),
      inquiry_field("Update data", c$basis_observation_ids)
    )
  )
}

assessment_details_ui <- function(a, c) {
  labels <- c(
    ineligible_evidence_exposure = "Evidence was not designated as unseen assessment data",
    protocol_identifier_mismatch = "The imported protocol differs from the commitment",
    units_or_conversion_mismatch = "Units or conversion differ from the committed rule",
    evidence_imported_before_commitment = "Evidence was imported before commitment",
    condition_mismatch = "A planned ID has a different condition label",
    unknown_observation_time = "A measured outcome has no documented time",
    outcome_before_or_at_commitment = "A measured outcome predates the collection window",
    outcome_after_deadline = "A measured outcome falls after the deadline",
    future_dated_outcome = "A measured outcome is dated in the future",
    repeated_measurement_unit = "Multiple IDs refer to the same measurement unit",
    incomplete_planned_measurements = "The planned measurements are incomplete",
    protocol_adherence_unconfirmed = "Protocol adherence has not been confirmed",
    computation_failure = "The observed comparison exceeded the numerical range"
  )
  shiny::tagList(
    shiny::tags$h4(test_status_label(a$status)),
    if (!is.null(a$observed)) {
      shiny::tags$p(sprintf(
        "Observed difference: %.3g %s. Frozen interval: %.3g to %.3g.",
        a$observed$difference,
        c$prediction$units,
        c$prediction$lower,
        c$prediction$upper
      ))
    },
    if (length(a$issues)) {
      shiny::tags$ul(lapply(a$issues, function(issue) {
        shiny::tags$li(unname(labels[[issue]]) %||% issue)
      }))
    },
    if (length(a$missing_ids)) {
      inquiry_field("Missing planned outcomes", a$missing_ids)
    },
    if (length(a$excluded_ids)) {
      inquiry_field(
        "Unplanned IDs excluded by the original rule",
        a$excluded_ids
      )
    },
    shiny::tags$p(a$interpretation),
    inquiry_field("Assessment time (UTC)", a$assessed_at),
    if (!is.null(a$reason)) inquiry_field("Reason", a$reason)
  )
}

prospective_server <- function(
  id,
  current,
  guard,
  prepare_import = function(c) NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    draft <- shiny::reactiveVal(NULL)
    assessment <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Plan the measurements and review the prediction before freezing it."
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    lineage <- shiny::reactive(current()$revisions[[1]]$claim$id)
    previous_lineage <- shiny::reactiveVal(shiny::isolate(lineage()))
    shiny::observeEvent(
      lineage(),
      {
        if (identical(lineage(), previous_lineage())) {
          return()
        }
        previous_lineage(lineage())
        draft(NULL)
        assessment(NULL)
        status(
          "Plan the measurements and review the prediction before freezing it."
        )
      },
      ignoreInit = TRUE,
      ignoreNULL = FALSE
    )
    selected <- shiny::reactive({
      if (is.null(input$assess_id) || !nzchar(input$assess_id)) {
        return(NULL)
      }
      ids <- vapply(current()$commitments, function(c) c$id, character(1))
      if (!input$assess_id %in% ids) {
        return(NULL)
      }
      find_test(current(), input$assess_id)
    })
    output$basis <- shiny::renderUI({
      x <- current()
      p <- utils::tail(x$revisions, 1)[[1]]$candidate
      if (is.null(p)) {
        return(shiny::tags$p(
          "Retain a numerical prior to plan this kind of test. You can still assess an earlier frozen prediction below."
        ))
      }
      updates <- Filter(
        function(a) a$revision == length(x$revisions),
        x$updates
      )
      choices <- c(
        "Original prior" = "",
        stats::setNames(
          vapply(updates, `[[`, character(1), "id"),
          vapply(
            updates,
            function(a) paste("Update:", a$reason, substr(a$id, 1, 8)),
            character(1)
          )
        )
      )
      previous <- c(
        "A new test" = "",
        stats::setNames(
          vapply(x$commitments, `[[`, character(1), "id"),
          vapply(
            x$commitments,
            function(c) paste(c$created_at, substr(c$id, 1, 8)),
            character(1)
          )
        )
      )
      shiny::tagList(
        shiny::selectInput(session$ns("basis_id"), "Prediction basis", choices),
        shiny::tags$p(sprintf(
          "Known measurement SDs: %s and %s %s. These are carried into the prediction; they are not estimated from future test data.",
          p$batch_sd[1],
          p$batch_sd[2],
          p$claim$units
        )),
        shiny::textInput(
          session$ns("low_label"),
          paste("CSV condition label for", p$conditions[1], p$condition_units),
          as.character(p$conditions[1])
        ),
        shiny::textAreaInput(
          session$ns("low_ids"),
          "Planned measurement IDs for the first condition (one per line)",
          width = "100%"
        ),
        shiny::textInput(
          session$ns("high_label"),
          paste("CSV condition label for", p$conditions[2], p$condition_units),
          as.character(p$conditions[2])
        ),
        shiny::textAreaInput(
          session$ns("high_ids"),
          "Planned measurement IDs for the second condition (one per line)",
          width = "100%"
        ),
        shiny::selectInput(
          session$ns("replaces"),
          "Earlier commitment being revised, if any",
          previous
        )
      )
    })
    config <- shiny::reactive({
      x <- current()
      p <- utils::tail(x$revisions, 1)[[1]]$candidate
      if (is.null(p)) {
        abort_suppose(
          "Retain a numerical prior before planning this test.",
          "unsupported"
        )
      }
      lines <- function(text) {
        values <- trimws(strsplit(text %||% "", "\n", fixed = TRUE)[[1]])
        values[nzchar(values)]
      }
      low <- lines(input$low_ids)
      high <- lines(input$high_ids)
      list(
        planned = data.frame(
          observation_id = c(low, high),
          condition = c(
            rep(input$low_label %||% "", length(low)),
            rep(input$high_label %||% "", length(high))
          )
        ),
        condition_map = stats::setNames(
          p$conditions,
          c(input$low_label %||% "", input$high_label %||% "")
        ),
        source = input$source,
        protocol = input$protocol,
        horizon = paste0(input$deadline_date, "T", input$deadline_time, "Z"),
        author = input$author,
        reason = input$reason,
        design = input$design,
        design_details = input$design_details,
        independent = input$independent,
        outcomes_unseen = input$unseen,
        coverage = input$coverage / 100,
        update_id = if (is.null(input$basis_id) || !nzchar(input$basis_id)) {
          NULL
        } else {
          input$basis_id
        },
        replaces = if (is.null(input$replaces) || !nzchar(input$replaces)) {
          NULL
        } else {
          input$replaces
        }
      )
    })
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        out <- do.call(commit_test, c(list(x = current()), config()))
        draft(list(
          commitment = utils::tail(out$commitments, 1)[[1]],
          base = proposal_basis_id(current()),
          config = config()
        ))
        status(
          "Review the prediction, planned IDs and collection deadline. Nothing has been committed yet."
        )
      })
    )
    shiny::observeEvent(
      input$freeze,
      safely({
        guard()
        p <- draft()
        if (is.null(p)) {
          abort_suppose("Preview the test first.")
        }
        if (
          !identical(p$base, proposal_basis_id(current())) ||
            !identical(p$config, config())
        ) {
          abort_suppose(
            "The record or plan changed. Preview again before freezing.",
            "stale"
          )
        }
        # Recreate at the actual commitment time; a preview cannot backdate it.
        current(do.call(commit_test, c(list(x = current()), config())))
        draft(NULL)
        shiny::updateCheckboxInput(session, "unseen", value = FALSE)
        status(
          "Prediction frozen. Later assessments and revisions will preserve this original commitment."
        )
      })
    )
    output$commit_preview <- shiny::renderUI({
      p <- draft()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        shiny::tags$h4("Review before freezing"),
        commitment_details_ui(p$commitment, current(), draft = TRUE),
        shiny::actionButton(session$ns("freeze"), "Freeze this prediction")
      )
    })
    output$selection <- shiny::renderUI({
      commitments <- current()$commitments
      if (!length(commitments)) {
        return(shiny::tags$p(
          "Freeze a prediction before assessing future outcomes."
        ))
      }
      ids <- vapply(commitments, `[[`, character(1), "id")
      chosen <- shiny::isolate(input$assess_id)
      if (is.null(chosen) || !chosen %in% ids) {
        chosen <- utils::tail(ids, 1)
      }
      shiny::selectInput(
        session$ns("assess_id"),
        "Frozen prediction to assess",
        stats::setNames(
          ids,
          vapply(
            commitments,
            function(c) {
              paste("Revision", c$revision, c$created_at, substr(c$id, 1, 8))
            },
            character(1)
          )
        ),
        selected = chosen
      )
    })
    output$selected <- shiny::renderUI({
      c <- selected()
      if (is.null(c)) {
        return(NULL)
      }
      shiny::tagList(
        inquiry_field(
          "Committed source and protocol",
          paste(c$source, c$protocol, sep = " / ")
        ),
        shiny::tags$p(test_prediction_text(c)),
        inquiry_field("Collection deadline", c$horizon)
      )
    })
    output$template <- shiny::downloadHandler(
      filename = function() {
        paste0(
          "suppose-planned-",
          substr(selected()$id %||% "test", 1, 12),
          ".csv"
        )
      },
      content = function(path) {
        c <- selected()
        shiny::req(c)
        planned <- data.frame(
          observation_id = vapply(
            c$planned,
            `[[`,
            character(1),
            "observation_id"
          ),
          condition = vapply(c$planned, `[[`, character(1), "condition"),
          outcome = NA_real_,
          batch = "",
          specimen = "",
          observed_at = ""
        )
        utils::write.csv(planned, path, row.names = FALSE, na = "")
      },
      contentType = "text/csv"
    )
    shiny::observeEvent(
      input$prepare_import,
      safely({
        guard()
        c <- selected()
        if (is.null(c)) {
          abort_suppose("Select a frozen prediction first.")
        }
        prepare_import(c)
      })
    )
    assessment_config <- shiny::reactive(list(
      commitment_id = input$assess_id,
      author = input$assessor,
      reason = input$assessment_reason,
      protocol_followed = input$protocol_followed
    ))
    shiny::observeEvent(
      input$preview_assessment,
      safely({
        guard()
        out <- do.call(assess_test, c(list(x = current()), assessment_config()))
        a <- utils::tail(out$assessments, 1)[[1]]
        assessment(list(
          result = a,
          base = proposal_basis_id(current()),
          config = assessment_config()
        ))
        status(
          "Assessment preview ready. Review completeness, timing and protocol before retaining it."
        )
      })
    )
    shiny::observeEvent(
      input$retain_assessment,
      safely({
        guard()
        p <- assessment()
        if (is.null(p)) {
          abort_suppose("Preview the assessment first.")
        }
        if (
          !identical(p$base, proposal_basis_id(current())) ||
            !identical(p$config, assessment_config())
        ) {
          abort_suppose(
            "The record or assessment inputs changed. Preview again.",
            "stale"
          )
        }
        out <- do.call(assess_test, c(list(x = current()), assessment_config()))
        a <- utils::tail(out$assessments, 1)[[1]]
        if (
          !identical(
            test_assessment_signature(a),
            test_assessment_signature(p$result)
          )
        ) {
          abort_suppose(
            "The assessment changed as time passed. Preview again before retaining it.",
            "stale"
          )
        }
        current(out)
        assessment(NULL)
        status(
          "Assessment retained beside its original commitment. Earlier results are unchanged."
        )
      })
    )
    output$assessment_preview <- shiny::renderUI({
      p <- assessment()
      if (is.null(p)) {
        return(NULL)
      }
      c <- find_test(current(), p$result$commitment_id)
      shiny::tagList(
        assessment_details_ui(p$result, c),
        shiny::plotOutput(session$ns("assessment_plot"), height = "220px"),
        shiny::actionButton(
          session$ns("retain_assessment"),
          "Retain this assessment"
        )
      )
    })
    output$assessment_plot <- shiny::renderPlot(
      {
        p <- assessment()
        shiny::req(p)
        print(plot_test(find_test(current(), p$result$commitment_id), p$result))
      },
      alt = shiny::reactive({
        p <- assessment()
        if (is.null(p)) "" else test_status_label(p$result$status)
      })
    )
    output$retained <- shiny::renderUI({
      lapply(current()$commitments, function(c) {
        assessments <- Filter(
          function(a) identical(a$commitment_id, c$id),
          current()$assessments
        )
        a <- if (length(assessments)) utils::tail(assessments, 1)[[1]] else NULL
        key <- paste0("test_", c$id)
        output[[key]] <- shiny::renderPlot(
          print(plot_test(c, a)),
          alt = test_prediction_text(c)
        )
        shiny::tags$details(
          shiny::tags$summary(paste(
            "Frozen",
            c$created_at,
            "(revision",
            paste0(c$revision, ")")
          )),
          commitment_details_ui(c, current()),
          shiny::plotOutput(session$ns(key), height = "220px"),
          lapply(assessments, function(a) {
            shiny::tags$details(
              shiny::tags$summary(paste(
                test_status_label(a$status),
                a$assessed_at
              )),
              assessment_details_ui(a, c)
            )
          })
        )
      })
    })
    output$status <- shiny::renderText(status())
    list(draft = draft, assessment = assessment, status = status)
  })
}
