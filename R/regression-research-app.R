regression_test_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("A future regression test"),
    shiny::p(
      "Preview and freeze a prediction from a reviewed regression, then attach and assess its actual future measurements. Unknown noise and joint uncertainty are retained."
    ),
    shiny::uiOutput(ns("retained")),
    shiny::tags$details(
      shiny::tags$summary("Prepare a regression commitment"),
      shiny::uiOutput(ns("model")),
      shiny::uiOutput(ns("plans")),
      shiny::actionButton(
        ns("use_plan"),
        "Use reviewed choice as starting settings"
      ),
      shiny::textAreaInput(
        ns("planned_csv"),
        "Future IDs, condition labels and predictor settings (CSV)",
        width = "100%",
        height = "170px"
      ),
      shiny::textInput(ns("source"), "Future dataset identifier"),
      shiny::textInput(ns("protocol"), "Collection protocol identifier"),
      shiny::textInput(
        ns("horizon"),
        "Collection deadline (UTC ISO 8601)",
        paste0(Sys.Date() + 7, "T23:59:59Z")
      ),
      shiny::textAreaInput(
        ns("target"),
        "What would these outcomes challenge?",
        width = "100%"
      ),
      shiny::selectInput(
        ns("design"),
        "Collection design",
        c("Observational" = "observational", "Intervention" = "intervention")
      ),
      shiny::textAreaInput(
        ns("design_details"),
        "Sampling or assignment procedure and limitations",
        width = "100%"
      ),
      shiny::selectInput(
        ns("rule"),
        "Frozen assessment rule",
        c(
          "All outcomes checked jointly" = "joint_outcomes",
          "Future sample mean B minus A" = "mean_difference"
        )
      ),
      shiny::numericInput(
        ns("coverage"),
        "Predictive probability",
        0.9,
        min = 0.01,
        max = 0.999
      ),
      shiny::textInput(
        ns("replaces"),
        "Earlier commitment to replace (optional ID)"
      ),
      shiny::actionButton(ns("preview"), "Preview regression test"),
      shiny::uiOutput(ns("incoming")),
      shiny::uiOutput(ns("preview_card"))
    ),
    shiny::tags$details(
      shiny::tags$summary("Attach and assess regression test outcomes"),
      shiny::uiOutput(ns("selection")),
      shiny::uiOutput(ns("selected")),
      shiny::downloadButton(
        ns("template"),
        "Download regression measurements CSV"
      ),
      shiny::p(
        "Fill actual outcomes, predictor settings, batch/specimen identities and UTC measurement times. The template contains planned settings; correct them if actual collection differed."
      ),
      shiny::fileInput(
        ns("data_file"),
        "Actual future measurements CSV",
        accept = ".csv"
      ),
      shiny::textInput(ns("actual_source"), "Actual dataset identifier"),
      shiny::textInput(ns("actual_protocol"), "Actual collection protocol"),
      shiny::textInput(ns("actual_units"), "Actual outcome units"),
      shiny::textInput(
        ns("actual_predictor_units"),
        "Actual predictor units (name=unit, separated by commas)"
      ),
      shiny::uiOutput(ns("corrections")),
      shiny::textAreaInput(
        ns("data_reason"),
        "Reason for this attachment or correction",
        width = "100%"
      ),
      shiny::checkboxInput(
        ns("data_unseen"),
        "These outcomes were unexamined when this test was frozen",
        FALSE
      ),
      shiny::actionButton(ns("preview_data"), "Review regression measurements"),
      shiny::uiOutput(ns("data_preview")),
      shiny::textAreaInput(
        ns("assessment_reason"),
        "Why record this assessment?",
        width = "100%"
      ),
      shiny::checkboxInput(
        ns("protocol_followed"),
        "I confirm the committed collection and independent-unit protocol was followed",
        FALSE
      ),
      shiny::actionButton(
        ns("preview_assessment"),
        "Preview regression assessment"
      ),
      shiny::uiOutput(ns("assessment_preview"))
    ),
    shiny::tags$div(role = "status", shiny::textOutput(ns("status")))
  )
}

regression_sensitivity_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Regression and design sensitivity"),
    shiny::p(
      "Compare one prior, likelihood, or decision-preference change at a time. Original fits, research plans and frozen tests stay unchanged."
    ),
    shiny::uiOutput(ns("model")),
    shiny::uiOutput(ns("plans")),
    shiny::actionButton(ns("use_plan"), "Use this plan's target contrast"),
    shiny::textAreaInput(
      ns("contrast_csv"),
      "Two settings for the mean contrast, second minus first (CSV)",
      width = "100%"
    ),
    shiny::tags$details(
      shiny::tags$summary("Choose sensitivity variants"),
      shiny::textInput(
        ns("powers"),
        "Powers, separated by commas",
        "0.8, 1, 1.25"
      ),
      shiny::checkboxGroupInput(
        ns("components"),
        "Model components (varied separately)",
        c("Joint prior" = "prior", "Likelihood" = "likelihood"),
        selected = c("prior", "likelihood")
      ),
      shiny::numericInput(
        ns("meaningful_gain"),
        "Scientifically meaningful mean gain (outcome units)",
        0
      ),
      shiny::textInput(
        ns("utility_thresholds"),
        "Optional utility thresholds for a decision plan, separated by commas",
        ""
      ),
      shiny::p(
        "Utility thresholds change only decision preferences. They are separate from the scientific gain threshold. Costs, feasibility, target settings and budget remain fixed."
      ),
      shiny::numericInput(
        ns("estimate_change"),
        "Estimate change needing review (outcome units)",
        1,
        min = 0
      ),
      shiny::numericInput(
        ns("probability_change"),
        "Probability change needing review (0 to 1)",
        0.05,
        min = 0,
        max = 1
      ),
      shiny::numericInput(
        ns("draws"),
        "Predictive-check replicates",
        1000,
        min = 200,
        max = 5000
      ),
      shiny::numericInput(ns("seed"), "Predictive-check seed", 1, min = 0)
    ),
    shiny::actionButton(ns("preview"), "Compare regression sensitivity"),
    shiny::uiOutput(ns("incoming")),
    shiny::uiOutput(ns("preview_card")),
    shiny::tags$div(role = "status", shiny::textOutput(ns("status"))),
    shiny::uiOutput(ns("retained"))
  )
}

regression_test_details <- function(c) {
  shiny::tagList(
    shiny::p(regression_test_text(c)),
    inquiry_field("Target", c$target),
    inquiry_field("Model review", c$regression_id),
    inquiry_field("Fit", c$fit_id),
    inquiry_field("Collection deadline", c$horizon),
    inquiry_field("Source / protocol", c(c$source, c$protocol)),
    inquiry_field("Sampling or assignment", c$design_details),
    if (any(c$prediction$outside_observed_range)) {
      shiny::p(
        "Some planned settings are outside observed predictor ranges. Range checks do not establish joint support or safe operation."
      )
    },
    shiny::tags$details(
      shiny::tags$summary("Planned settings and assumptions"),
      shiny::tags$pre(paste(
        utils::capture.output(utils::write.csv(
          do.call(rbind, lapply(c$planned, as.data.frame)),
          row.names = FALSE
        )),
        collapse = "\n"
      )),
      shiny::tags$ul(lapply(c$assumptions, shiny::tags$li))
    )
  )
}

regression_sensitivity_label <- function(v) {
  if (v$component == "utility") {
    paste("Utility threshold", v$design$threshold)
  } else if (v$component == "reference") {
    "Original model"
  } else {
    paste(v$component, "power", v$power)
  }
}

regression_sensitivity_details <- function(s) {
  shiny::tagList(
    shiny::p(paste(s$interpretation, collapse = " ")),
    shiny::tags$div(
      class = "table-responsive",
      role = "region",
      tabindex = "0",
      `aria-label` = "Sensitivity comparison",
      shiny::tags$table(
        class = "table table-sm",
        shiny::tags$caption(paste(
          "Mean contrast and unknown noise in",
          s$units
        )),
        shiny::tags$thead(shiny::tags$tr(lapply(
          c(
            "Variant",
            "Mean",
            "P(gain above threshold)",
            "Noise SD median",
            "Design choice"
          ),
          shiny::tags$th
        ))),
        shiny::tags$tbody(lapply(s$variants, function(v) {
          shiny::tags$tr(
            shiny::tags$td(paste(
              regression_sensitivity_label(v),
              if (v$review_flag) "(review)"
            )),
            shiny::tags$td(sprintf("%.3g", v$contrast$mean)),
            shiny::tags$td(sprintf(
              "%.1f%%",
              100 * v$contrast$probability_above
            )),
            shiny::tags$td(sprintf("%.3g", v$noise$median)),
            shiny::tags$td(
              if (is.null(v$design)) {
                "Not compared"
              } else if (length(v$design$recommended)) {
                paste(v$design$recommended, collapse = ", ")
              } else {
                "None"
              }
            )
          )
        }))
      )
    ),
    shiny::p(sprintf(
      "Scientific gain threshold: %.4g %s. Review flags use estimate change > %.4g or probability change > %.3g, or a changed design recommendation.",
      s$meaningful_gain,
      s$units,
      s$estimate_change,
      s$probability_change
    )),
    shiny::tags$details(
      shiny::tags$summary("Predictive checks and candidate comparisons"),
      lapply(s$variants, function(v) {
        shiny::tagList(
          shiny::tags$h5(regression_sensitivity_label(v)),
          if (v$component == "utility") {
            shiny::p("Predictive checks are unchanged from the original model.")
          },
          lapply(v$checks, function(c) {
            shiny::p(paste(
              c$statistic,
              c$status,
              sprintf("tail area %.3g", c$tail_area)
            ))
          }),
          if (!is.null(v$design)) {
            shiny::tags$pre(paste(
              utils::capture.output(print(
                do.call(rbind, lapply(v$design$candidates, as.data.frame)),
                row.names = FALSE
              )),
              collapse = "\n"
            ))
          }
        )
      })
    )
  )
}

regression_sensitivity_plot <- function(s) {
  d <- do.call(
    rbind,
    lapply(s$variants, function(v) {
      data.frame(
        variant = regression_sensitivity_label(v),
        mean = v$contrast$mean,
        lower = v$contrast$lower,
        upper = v$contrast$upper
      )
    })
  )
  d$variant <- factor(d$variant, levels = rev(unique(d$variant)))
  ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$mean,
      y = .data$variant,
      xmin = .data$lower,
      xmax = .data$upper
    )
  ) +
    ggdist::geom_pointinterval(colour = "#633b83") +
    ggplot2::geom_vline(
      xintercept = s$meaningful_gain,
      linetype = 2,
      colour = "#b74d08"
    ) +
    ggplot2::labs(
      x = paste("Mean difference (", s$units, ")", sep = ""),
      y = NULL,
      subtitle = "Central 90% intervals; dashed line is the scientific threshold"
    ) +
    ggplot2::theme_minimal(base_size = 12)
}

regression_review_server <- function(
  id,
  current,
  guard,
  form,
  draft = function() NULL,
  author = function() "You",
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    preview <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Choose a reviewed regression and prepare settings, or ask chat for a draft."
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    numeric_csv <- function(s) {
      if (is.null(s) || !nzchar(trimws(s))) {
        numeric()
      } else {
        suppressWarnings(as.numeric(trimws(strsplit(s, ",", fixed = TRUE)[[
          1
        ]])))
      }
    }
    defaults <- function() {
      if (form == "regression_test") {
        regression_test_form_defaults(current())
      } else {
        regression_sensitivity_form_defaults(current())
      }
    }
    output$model <- shiny::renderUI({
      entries <- Filter(
        function(e) e$choice != "neither",
        current()$regressions
      )
      shiny::selectInput(
        session$ns("regression_id"),
        "Reviewed regression",
        stats::setNames(
          vapply(entries, `[[`, character(1), "id"),
          vapply(
            entries,
            function(e) paste(e$choice, substr(e$id, 1, 8), e$reason),
            character(1)
          )
        ),
        selected = shiny::isolate(input$regression_id) %||%
          if (length(entries)) utils::tail(entries, 1)[[1]]$id else ""
      )
    })
    output$plans <- shiny::renderUI({
      plans <- current()$research_designs
      name <- if (form == "regression_test") "plan_id" else "design_id"
      shiny::selectInput(
        session$ns(name),
        "Optional reviewed research plan",
        c(
          "Separate from research plans" = "",
          stats::setNames(
            vapply(plans, `[[`, character(1), "id"),
            vapply(plans, function(e) paste(e$choice, e$reason), character(1))
          )
        ),
        selected = shiny::isolate(input[[name]]) %||% ""
      )
    })
    values <- shiny::reactive({
      if (
        !length(Filter(
          function(e) e$choice != "neither",
          current()$regressions
        ))
      ) {
        return(list())
      }
      v <- defaults()
      for (name in names(v)) {
        value <- if (name %in% c("powers", "utility_thresholds")) {
          if (is.null(input[[name]])) v[[name]] else numeric_csv(input[[name]])
        } else {
          input[[name]] %||% v[[name]]
        }
        v[name] <- list(value)
      }
      v
    })
    form_state <- shiny::reactive(list(
      values = values(),
      version = object_id(values())
    ))
    update <- function(v) {
      for (name in names(v)) {
        if (
          name %in% c("regression_id", "plan_id", "design_id", "rule", "design")
        ) {
          shiny::updateSelectInput(session, name, selected = v[[name]])
        } else if (name == "components") {
          shiny::updateCheckboxGroupInput(session, name, selected = v[[name]])
        } else if (name %in% c("powers", "utility_thresholds")) {
          shiny::updateTextInput(
            session,
            name,
            value = paste(v[[name]], collapse = ", ")
          )
        } else if (is.numeric(v[[name]])) {
          shiny::updateNumericInput(session, name, value = v[[name]])
        } else if (
          name %in% c("planned_csv", "contrast_csv", "target", "design_details")
        ) {
          shiny::updateTextAreaInput(session, name, value = v[[name]])
        } else {
          shiny::updateTextInput(session, name, value = v[[name]])
        }
      }
    }
    apply_draft <- function(d) {
      check_seal(d, "suppose_form_draft")
      if (!identical(d$base_id, proposal_basis_id(current()))) {
        abort_suppose("Refresh this draft against the current record.", "stale")
      }
      p <- workbench_form_preview(current(), form, d$values)
      update(p$values)
      preview(p)
      source(d)
      incoming(NULL)
      shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
      status(
        "Suggested settings are ready for human review. Nothing has been frozen or retained."
      )
    }
    shiny::observeEvent(
      draft(),
      safely({
        d <- draft()
        if (
          !is.null(d$form_base_id) &&
            !identical(d$form_base_id, form_state()$version)
        ) {
          incoming(d)
          status(
            "Manual edits are preserved. Choose whether to use the incoming draft."
          )
        } else {
          apply_draft(d)
        }
      })
    )
    output$incoming <- shiny::renderUI(
      if (!is.null(incoming())) {
        shiny::actionButton(
          session$ns("use_chat"),
          "Use incoming research draft"
        )
      }
    )
    shiny::observeEvent(
      input$use_chat,
      safely({
        guard()
        shiny::req(incoming())
        apply_draft(incoming())
      })
    )
    shiny::observeEvent(
      input$use_plan,
      safely({
        guard()
        name <- if (form == "regression_test") "plan_id" else "design_id"
        shiny::req(nzchar(input[[name]]))
        settings <- research_design_settings(current(), input[[name]])
        v <- values()
        v$regression_id <- settings$regression_id
        if (form == "regression_test") {
          e <- research_plan(current(), input$plan_id)
          if (e$choice == "none") {
            abort_suppose("A declined plan cannot become a commitment.", "plan")
          }
          chosen <- settings$candidates[
            settings$candidates$candidate_id == e$choice,
            ,
            drop = FALSE
          ]
          planned <- data.frame(
            observation_id = sprintf("future-%03d", seq_len(chosen$repeats)),
            condition = "planned"
          )
          for (n in names(e$design$predictor_units)) {
            planned[[n]] <- chosen[[n]]
          }
          v$planned_csv <- paste(
            utils::capture.output(utils::write.csv(planned, row.names = FALSE)),
            collapse = "\n"
          )
          v$rule <- "joint_outcomes"
        } else {
          v$contrast_csv <- paste(
            utils::capture.output(utils::write.csv(
              settings$contrast,
              row.names = FALSE
            )),
            collapse = "\n"
          )
        }
        update(v)
        preview(NULL)
        source(NULL)
        status(
          "Reviewed settings copied as starting values. Check the proposed IDs and collection details, then preview and review. Nothing is frozen."
        )
      })
    )
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        shiny::req(length(values()))
        preview(workbench_form_preview(current(), form, values()))
        if (
          !is.null(source()) &&
            !identical(source()$base_id, proposal_basis_id(current()))
        ) {
          source(NULL)
        }
        shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
        status("Review the computed consequences before retaining this choice.")
      })
    )
    output$preview_card <- shiny::renderUI({
      shiny::req(preview())
      shiny::tagList(
        form_draft_notice(source()),
        if (form == "regression_test") {
          regression_test_details(preview()$fit)
        } else {
          shiny::tagList(
            regression_sensitivity_details(preview()$fit),
            shiny::plotOutput(session$ns("sensitivity_plot"), height = "420px")
          )
        },
        shiny::textAreaInput(
          session$ns("reason"),
          "Your review reason and remaining limitations",
          width = "100%"
        ),
        if (form == "regression_test") {
          shiny::tagList(
            shiny::checkboxInput(
              session$ns("independent"),
              "The planned measurements are independent units",
              FALSE
            ),
            shiny::checkboxInput(
              session$ns("unseen"),
              "The designated outcomes are unexamined",
              FALSE
            )
          )
        },
        shiny::checkboxInput(
          session$ns("reviewed"),
          "I reviewed the assumptions, prediction and limitations",
          FALSE
        ),
        shiny::actionButton(
          session$ns("retain"),
          if (form == "regression_test") {
            "Freeze regression test"
          } else {
            "Retain regression sensitivity"
          }
        )
      )
    })
    output$sensitivity_plot <- shiny::renderPlot(
      {
        shiny::req(preview(), form == "regression_sensitivity")
        regression_sensitivity_plot(preview()$fit)
      },
      alt = "Mean contrast intervals for each prior, likelihood or preference variant; numerical summaries and limitations appear above."
    )
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        shiny::req(preview())
        if (!identical(object_id(values()), object_id(preview()$values))) {
          abort_suppose(
            "Settings changed. Preview again before retaining.",
            "stale"
          )
        }
        if (!isTRUE(input$reviewed)) {
          abort_suppose("Confirm your review before retaining.", "review")
        }
        out <- if (form == "regression_test") {
          commit_regression_test(
            current(),
            preview()$fit,
            author(),
            input$reason,
            input$independent,
            input$unseen,
            source()
          )
        } else {
          record_regression_sensitivity(
            current(),
            preview()$fit,
            author(),
            input$reason,
            TRUE,
            source()
          )
        }
        current(out)
        preview(NULL)
        source(NULL)
        incoming(NULL)
        retained()
        status(
          if (form == "regression_test") {
            "Regression prediction frozen. Collect only the designated future measurements; no experiment has been executed."
          } else {
            "Sensitivity review retained. Original fits, plans and tests are unchanged."
          }
        )
      })
    )
    if (form == "regression_test") {
      bind_regression_test_assessment(
        input,
        output,
        session,
        current,
        guard,
        author,
        safely,
        status
      )
    } else {
      output$retained <- shiny::renderUI(lapply(
        current()$regression_sensitivities,
        function(e) {
          key <- paste0("sensitivity_", e$id)
          output[[key]] <- shiny::renderPlot(
            regression_sensitivity_plot(e$result),
            alt = paste(e$result$interpretation, collapse = " ")
          )
          shiny::tags$details(
            shiny::tags$summary(paste(
              "Reviewed regression sensitivity:",
              e$reason
            )),
            inquiry_field("Reviewer", e$author),
            form_draft_notice(e$form_draft),
            regression_sensitivity_details(e$result),
            shiny::plotOutput(session$ns(key), height = "420px")
          )
        }
      ))
    }
    output$status <- shiny::renderText(status())
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        preview(NULL)
        source(NULL)
        incoming(NULL)
      },
      ignoreInit = TRUE
    )
    list(
      preview = preview,
      source = source,
      incoming = incoming,
      status = status,
      form_state = form_state,
      restore = function(d) safely(apply_draft(d))
    )
  })
}

bind_regression_test_assessment <- function(
  input,
  output,
  session,
  current,
  guard,
  author,
  safely,
  status
) {
  staged_data <- shiny::reactiveVal(NULL)
  staged_assessment <- shiny::reactiveVal(NULL)
  selected <- shiny::reactive({
    shiny::req(input$commitment_id)
    regression_commitment(current(), input$commitment_id)
  })
  output$selection <- shiny::renderUI({
    entries <- current()$regression_commitments
    shiny::selectInput(
      session$ns("commitment_id"),
      "Frozen regression test",
      stats::setNames(
        vapply(entries, `[[`, character(1), "id"),
        vapply(
          entries,
          function(c) paste(c$target, substr(c$id, 1, 8)),
          character(1)
        )
      ),
      selected = shiny::isolate(input$commitment_id) %||%
        if (length(entries)) utils::tail(entries, 1)[[1]]$id else ""
    )
  })
  output$selected <- shiny::renderUI(regression_test_details(selected()))
  output$corrections <- shiny::renderUI({
    entries <- regression_active_test_data(current(), selected()$id)
    shiny::selectInput(
      session$ns("supersedes"),
      "Correction of an attachment (optional)",
      c(
        "New measurements" = "",
        stats::setNames(
          vapply(entries, `[[`, character(1), "id"),
          vapply(
            entries,
            function(e) {
              paste(length(e$data$rows), "rows:", e$reason, substr(e$id, 1, 8))
            },
            character(1)
          )
        )
      ),
      selected = ""
    )
  })
  shiny::observeEvent(input$commitment_id, {
    c <- selected()
    shiny::updateTextInput(session, "actual_source", value = c$source)
    shiny::updateTextInput(session, "actual_protocol", value = c$protocol)
    shiny::updateTextInput(session, "actual_units", value = c$prediction$units)
    shiny::updateTextInput(
      session,
      "actual_predictor_units",
      value = paste(
        names(c$predictor_units),
        unlist(c$predictor_units),
        sep = "=",
        collapse = ", "
      )
    )
    staged_data(NULL)
    staged_assessment(NULL)
  })
  output$template <- shiny::downloadHandler(
    filename = function() "regression-future-measurements.csv",
    content = function(file) {
      c <- selected()
      d <- do.call(rbind, lapply(c$planned, as.data.frame))
      d$outcome <- NA_real_
      d$batch <- d$observation_id
      d$specimen <- d$observation_id
      d$observed_at <- "unknown"
      utils::write.csv(d, file, row.names = FALSE, na = "")
    }
  )
  data_signature <- shiny::reactive(object_id(list(
    input$commitment_id,
    input$data_file,
    input$actual_source,
    input$actual_protocol,
    input$actual_units,
    input$actual_predictor_units,
    input$supersedes,
    input$data_reason,
    input$data_unseen,
    author()
  )))
  shiny::observeEvent(
    input$preview_data,
    safely({
      guard()
      shiny::req(input$data_file)
      d <- measurement_table(paste(
        readLines(input$data_file$datapath, warn = FALSE),
        collapse = "\n"
      ))
      for (name in c("outcome", names(selected()$predictor_units))) {
        raw <- d[[name]]
        if (is.null(raw)) {
          abort_suppose(
            "The measurements CSV is missing a required numeric column.",
            "data"
          )
        }
        value <- suppressWarnings(as.numeric(raw))
        if (any(is.na(value) & !is.na(raw))) {
          abort_suppose(
            "Measurement outcomes and settings must be numeric or explicitly missing.",
            "data"
          )
        }
        d[[name]] <- value
      }
      parts <- strsplit(input$actual_predictor_units, ",", fixed = TRUE)[[1]]
      pairs <- lapply(parts, function(p) {
        trimws(strsplit(p, "=", fixed = TRUE)[[1]])
      })
      if (!length(pairs) || any(lengths(pairs) != 2L)) {
        abort_suppose("Use predictor=unit pairs separated by commas.", "units")
      }
      units <- stats::setNames(
        vapply(pairs, `[[`, character(1), 2),
        vapply(pairs, `[[`, character(1), 1)
      )
      out <- record_regression_test_data(
        current(),
        selected()$id,
        d,
        input$actual_source,
        input$actual_protocol,
        input$actual_units,
        units,
        author(),
        input$data_reason,
        input$data_unseen,
        if (nzchar(input$supersedes %||% "")) input$supersedes else NULL
      )
      staged_data(list(
        record = out,
        basis = proposal_basis_id(current()),
        signature = data_signature()
      ))
      status(
        "Measurement copy is ready for review. Nothing has been attached yet."
      )
    })
  )
  output$data_preview <- shiny::renderUI({
    shiny::req(staged_data())
    e <- utils::tail(staged_data()$record$regression_test_data, 1)[[1]]
    shiny::tagList(
      shiny::p(paste(
        length(e$data$rows),
        "planned measurements;",
        length(e$data$missing_ids),
        "missing outcomes."
      )),
      inquiry_field(
        "Actual source / protocol",
        c(e$data$source, e$data$protocol)
      ),
      inquiry_field(
        "Actual predictor units",
        paste(
          names(e$predictor_units),
          unlist(e$predictor_units),
          collapse = "; "
        )
      ),
      shiny::tags$details(
        shiny::tags$summary("Inspect actual outcomes and settings"),
        shiny::tags$pre(as.character(json_data(
          list(rows = e$data$rows, settings = e$settings),
          pretty = TRUE
        )))
      ),
      shiny::checkboxInput(
        session$ns("data_reviewed"),
        "I reviewed the actual measurements and provenance",
        FALSE
      ),
      shiny::actionButton(
        session$ns("retain_data"),
        "Attach reviewed regression measurements"
      )
    )
  })
  shiny::observeEvent(
    input$retain_data,
    safely({
      guard()
      shiny::req(staged_data())
      if (!isTRUE(input$data_reviewed)) {
        abort_suppose("Review the measurements before attaching.", "review")
      }
      if (
        !identical(staged_data()$basis, proposal_basis_id(current())) ||
          !identical(staged_data()$signature, data_signature())
      ) {
        abort_suppose(
          "The record or import settings changed. Review the measurements again.",
          "stale"
        )
      }
      current(staged_data()$record)
      staged_data(NULL)
      staged_assessment(NULL)
      status(
        "Regression test measurements retained. Earlier evidence and assessments are unchanged."
      )
    })
  )
  assessment_signature <- shiny::reactive(object_id(list(
    input$commitment_id,
    input$assessment_reason,
    input$protocol_followed,
    author()
  )))
  shiny::observeEvent(
    input$preview_assessment,
    safely({
      guard()
      out <- assess_regression_test(
        current(),
        selected()$id,
        author(),
        input$assessment_reason,
        input$protocol_followed %||% FALSE
      )
      staged_assessment(list(
        record = out,
        basis = proposal_basis_id(current()),
        signature = assessment_signature()
      ))
      status(
        "Assessment preview only. Review the evidence versions and outcome before retaining."
      )
    })
  )
  output$assessment_preview <- shiny::renderUI({
    shiny::req(staged_assessment())
    a <- utils::tail(staged_assessment()$record$regression_assessments, 1)[[1]]
    shiny::tagList(
      regression_assessment_details(a),
      shiny::actionButton(
        session$ns("retain_assessment"),
        "Retain regression assessment"
      )
    )
  })
  shiny::observeEvent(
    input$retain_assessment,
    safely({
      guard()
      shiny::req(staged_assessment())
      if (
        !identical(staged_assessment()$basis, proposal_basis_id(current())) ||
          !identical(staged_assessment()$signature, assessment_signature())
      ) {
        abort_suppose(
          "The evidence or assessment settings changed. Preview again.",
          "stale"
        )
      }
      current(staged_assessment()$record)
      staged_assessment(NULL)
      status("Assessment retained against the original frozen prediction.")
    })
  )
  output$retained <- shiny::renderUI(lapply(
    current()$regression_commitments,
    function(c) {
      assessments <- Filter(
        function(a) identical(a$commitment_id, c$id),
        current()$regression_assessments
      )
      shiny::tags$details(
        shiny::tags$summary(paste("Frozen regression test:", c$target)),
        inquiry_field("Frozen at", c$created_at),
        inquiry_field("Committed by", c$author),
        form_draft_notice(c$form_draft),
        regression_test_details(c),
        lapply(assessments, function(a) {
          shiny::tags$details(
            shiny::tags$summary(paste(
              test_status_label(a$status),
              a$assessed_at
            )),
            regression_assessment_details(a)
          )
        })
      )
    }
  ))
  invisible(NULL)
}

regression_assessment_details <- function(a) {
  shiny::tagList(
    shiny::tags$h4(test_status_label(a$status)),
    inquiry_field("Issues", a$issues),
    inquiry_field("Missing measurements", a$missing_ids),
    if (!is.null(a$observed)) {
      inquiry_field("Frozen-rule comparison", unlist(a$observed))
    },
    inquiry_field("Evidence versions", a$evidence_ids),
    shiny::p(a$interpretation)
  )
}
