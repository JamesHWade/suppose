sensitivity_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Check sensitivity"),
    shiny::tags$p(
      "See how a retained update changes when prior strength or likelihood weight changes. Review comparisons before saving them."
    ),
    shiny::uiOutput(ns("selection")),
    shiny::uiOutput(ns("incoming")),
    shiny::tags$p(
      "Default setup: the latest update, both components at powers 0.8, 1 and 1.25, and all output comparisons. Review thresholds start at 1 outcome unit and 5 percentage points. Current selections and results appear below."
    ),
    shiny::tags$details(
      shiny::tags$summary("Adjust comparison settings"),
      shiny::checkboxGroupInput(
        ns("components"),
        "Assumptions to vary separately",
        c("Prior strength" = "prior", "Likelihood weight" = "likelihood"),
        selected = c("prior", "likelihood")
      ),
      shiny::textInput(
        ns("powers"),
        "Powers to compare (comma separated; 1 is original)",
        "0.8, 1, 1.25"
      ),
      shiny::checkboxGroupInput(
        ns("quantities"),
        "Outputs to review",
        c(
          "Mean difference" = "estimate",
          "Probability above the claim threshold" = "probability",
          "Retained test assessments" = "assessment"
        ),
        selected = c("estimate", "probability", "assessment")
      ),
      shiny::numericInput(
        ns("estimate_change"),
        "Mean-difference change worth reviewing (outcome units)",
        1,
        min = 0.000001
      ),
      shiny::numericInput(
        ns("probability_change"),
        "Probability change worth reviewing (percentage points)",
        5,
        min = 0.000001,
        max = 100
      ),
      shiny::textInput(
        ns("reason"),
        "Why retain this sensitivity comparison?",
        "Review dependence on prior strength and likelihood weight"
      ),
      shiny::tags$p(
        "A power above 1 strengthens that component; below 1 weakens it. This checks the full joint prior or full likelihood, one at a time. It does not change the prior shape, independence assumption or physical measurement SDs."
      )
    ),
    shiny::actionButton(ns("preview"), "Preview sensitivity"),
    shiny::uiOutput(ns("preview_card")),
    shiny::tags$div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    ),
    shiny::uiOutput(ns("retained")),
    shiny::actionButton(
      ns("followup"),
      "Draft a review of the latest retained sensitivity in chat"
    )
  )
}

sensitivity_details_ui <- function(s) {
  shiny::tagList(
    shiny::tags$p(s$scope),
    shiny::tags$p(paste(
      "Original prior predictive check:",
      sensitivity_check_label(
        s$baseline_diagnostics$prior_predictive_conflict$status
      ),
      "; measurement variation checks:",
      paste(
        vapply(
          s$baseline_diagnostics$measurement_variation,
          function(d) sensitivity_check_label(d$status),
          character(1)
        ),
        collapse = ", "
      ),
      ". These model checks are separate from numerical completion."
    )),
    shiny::tags$p(sprintf(
      "Original mean difference %.3g %s; central 90%% interval %.3g to %.3g; probability above %.3g: %.1f%%.",
      s$baseline$mean,
      s$units,
      s$baseline$lower,
      s$baseline$upper,
      s$threshold,
      100 * s$baseline$probability_above
    )),
    shiny::tags$p(sprintf(
      "Review thresholds: %.3g %s mean change; %.3g percentage points probability change. Only selected outputs trigger review.",
      s$estimate_threshold,
      s$units,
      100 * s$probability_threshold
    )),
    shiny::tags$div(
      style = "overflow-x:auto",
      shiny::tags$table(
        class = "table table-sm",
        shiny::tags$caption(
          "One component changes at a time. Failed rows have no estimate."
        ),
        shiny::tags$thead(shiny::tags$tr(
          shiny::tags$th("Component"),
          shiny::tags$th("Power"),
          if ("estimate" %in% s$quantities) {
            shiny::tags$th(paste("Mean", s$units))
          },
          if ("probability" %in% s$quantities) shiny::tags$th("Probability"),
          shiny::tags$th("Result")
        )),
        shiny::tags$tbody(lapply(s$rows, function(r) {
          shiny::tags$tr(
            shiny::tags$td(
              if (r$component == "prior") "Prior" else "Likelihood"
            ),
            shiny::tags$td(format(r$power)),
            if ("estimate" %in% s$quantities) {
              shiny::tags$td(
                if (is.null(r$target)) {
                  "\u2014"
                } else {
                  sprintf("%.3g", r$target$mean)
                }
              )
            },
            if ("probability" %in% s$quantities) {
              shiny::tags$td(
                if (is.null(r$target)) {
                  "\u2014"
                } else {
                  sprintf("%.1f%%", 100 * r$target$probability_above)
                }
              )
            },
            shiny::tags$td(
              if (r$status == "failed") {
                r$error
              } else if (
                r$review_estimate || r$review_probability || r$review_assessment
              ) {
                "Review change"
              } else {
                "Computed"
              }
            )
          )
        }))
      )
    ),
    shiny::tags$h4("What should be reviewed next?"),
    shiny::tags$ul(lapply(s$followup, shiny::tags$li)),
    if ("assessment" %in% s$quantities) {
      shiny::tags$details(
        shiny::tags$summary("Comparison with retained test assessments"),
        shiny::tags$p(
          "These are exploratory alternative intervals. Original frozen predictions and assessments remain unchanged. Physical future measurement variation is held fixed."
        ),
        if (!length(s$assessment_ids)) {
          shiny::tags$p(
            "No test assessments were attached when this analysis was computed."
          )
        },
        lapply(s$rows, function(r) {
          if (!length(r$assessments)) {
            return(NULL)
          }
          shiny::tags$details(
            shiny::tags$summary(paste(r$component, "power", r$power)),
            lapply(r$assessments, function(a) {
              shiny::tagList(
                inquiry_field("Assessment reference", a$assessment_id),
                inquiry_field(
                  "Original assessment",
                  test_status_label(a$original_status)
                ),
                inquiry_field("Alternative comparison", a$status),
                if (!is.null(a$lower)) {
                  shiny::tags$p(sprintf(
                    "Alternative interval %.3g to %.3g; original interval %.3g to %.3g; observed %.3g.",
                    a$lower,
                    a$upper,
                    a$original_lower,
                    a$original_upper,
                    a$observed
                  ))
                },
                shiny::tags$p(a$reason)
              )
            })
          )
        })
      )
    },
    shiny::tags$details(
      shiny::tags$summary("Exact analysis references"),
      inquiry_field("Analysis", s$id),
      inquiry_field("Update", s$update_id),
      inquiry_field("Prior", s$prior_id),
      inquiry_field("Claim", s$claim_id),
      inquiry_field("Revision", s$revision),
      inquiry_field("Evidence", s$evidence_ids),
      inquiry_field("Computed", s$created_at)
    )
  )
}

sensitivity_server <- function(
  id,
  current,
  guard,
  followup = function(text) NULL,
  draft = function() NULL,
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    staged <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Choose a retained update and the assumptions to check."
    )
    previous_lineage <- shiny::reactiveVal(shiny::isolate(
      current()$revisions[[1]]$claim$id
    ))
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        lineage <- current()$revisions[[1]]$claim$id
        if (identical(lineage, previous_lineage())) {
          return()
        }
        previous_lineage(lineage)
        staged(NULL)
        source(NULL)
        incoming(NULL)
        status("Choose a retained update and the assumptions to check.")
      },
      ignoreInit = TRUE,
      ignoreNULL = FALSE
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    form_values <- shiny::reactive(list(
      update_id = input$update_id,
      powers = if (is.null(input$powers)) {
        NULL
      } else {
        suppressWarnings(as.numeric(trimws(strsplit(
          input$powers,
          ",",
          fixed = TRUE
        )[[1]])))
      },
      components = input$components,
      quantities = input$quantities,
      estimate_change = input$estimate_change,
      probability_change = if (is.null(input$probability_change)) {
        NULL
      } else {
        input$probability_change / 100
      }
    ))
    config <- shiny::reactive(list(
      input$update_id,
      input$powers,
      input$components,
      input$quantities,
      input$estimate_change,
      input$probability_change,
      input$reason
    ))
    output$selection <- shiny::renderUI({
      updates <- current()$updates
      if (!length(updates)) {
        return(shiny::tags$p(
          "Retain an update under Learn from measurements first."
        ))
      }
      choices <- stats::setNames(
        vapply(updates, `[[`, character(1), "id"),
        vapply(
          updates,
          function(u) {
            paste("Revision", u$revision, u$reason, substr(u$id, 1, 8))
          },
          character(1)
        )
      )
      shiny::selectInput(
        session$ns("update_id"),
        "Retained update to inspect",
        choices,
        selected = if (
          isTRUE(shiny::isolate(input$update_id) %in% unname(choices))
        ) {
          shiny::isolate(input$update_id)
        } else {
          utils::tail(unname(choices), 1)
        }
      )
    })
    apply_chat_draft <- function(d) {
      check_seal(d, "suppose_form_draft")
      if (!identical(d$base_id, proposal_basis_id(current()))) {
        status(
          "This chat draft belongs to an earlier record. Ask chat to refresh it."
        )
        return()
      }
      incoming(NULL)
      prepared <- workbench_form_preview(current(), "sensitivity", d$values)
      v <- prepared$values
      powers_text <- paste(v$powers, collapse = ", ")
      shiny::updateSelectInput(session, "update_id", selected = v$update_id)
      shiny::updateTextInput(session, "powers", value = powers_text)
      shiny::updateCheckboxGroupInput(
        session,
        "components",
        selected = v$components
      )
      shiny::updateCheckboxGroupInput(
        session,
        "quantities",
        selected = v$quantities
      )
      shiny::updateNumericInput(
        session,
        "estimate_change",
        value = v$estimate_change
      )
      shiny::updateNumericInput(
        session,
        "probability_change",
        value = 100 * v$probability_change
      )
      shiny::updateTextInput(session, "reason", value = d$reason)
      source(d)
      staged(list(
        fit = prepared$fit,
        base = proposal_basis_id(current()),
        config = list(
          v$update_id,
          powers_text,
          v$components,
          v$quantities,
          v$estimate_change,
          100 * v$probability_change,
          d$reason
        )
      ))
      status(
        "Chat filled the form and prepared a preview. Review the suggested settings before retaining."
      )
    }
    shiny::observeEvent(
      draft(),
      safely({
        d <- draft()
        if (
          !is.null(d$form_base_id) &&
            !identical(
              d$form_base_id,
              object_id(list(values = form_values(), reason = input$reason))
            )
        ) {
          incoming(d)
          status(
            "You edited this form while chat was working. Your edits are kept; review the incoming suggestion before replacing them."
          )
          return()
        }
        apply_chat_draft(d)
      })
    )
    shiny::observeEvent(
      input$use_chat_draft,
      safely({
        guard()
        shiny::req(incoming())
        apply_chat_draft(incoming())
      })
    )
    output$incoming <- shiny::renderUI({
      d <- incoming()
      if (is.null(d)) {
        return(NULL)
      }
      shiny::tagList(
        form_draft_notice(d),
        shiny::actionButton(
          session$ns("use_chat_draft"),
          "Use chat draft instead of my newer edits"
        )
      )
    })
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        check_text(input$powers, "powers")
        tokens <- trimws(strsplit(input$powers, ",", fixed = TRUE)[[1]])
        if (grepl(",$", trimws(input$powers)) || !all(nzchar(tokens))) {
          abort_suppose("Enter a comma-separated list of numeric powers.")
        }
        powers <- suppressWarnings(as.numeric(tokens))
        fit <- sensitivity_analysis(
          current(),
          input$update_id,
          powers,
          input$components,
          input$quantities,
          input$estimate_change,
          input$probability_change / 100
        )
        check_text(input$reason, "reason")
        staged(list(
          fit = fit,
          config = config(),
          base = proposal_basis_id(current())
        ))
        status(
          "Review the scope, changes and failed computations before retaining this analysis."
        )
      })
    )
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        p <- staged()
        if (is.null(p)) {
          abort_suppose("Preview sensitivity first.")
        }
        if (
          !identical(object_id(p$config), object_id(config())) ||
            !identical(p$base, proposal_basis_id(current()))
        ) {
          abort_suppose(
            "The record or inputs changed. Preview again before retaining.",
            "stale"
          )
        }
        d <- source()
        if (!is.null(d) && !identical(d$base_id, p$fit$basis_id)) {
          d <- NULL
        }
        current(record_sensitivity(
          current(),
          p$fit,
          input$reason,
          form_draft = d
        ))
        staged(NULL)
        source(NULL)
        retained()
        status(
          "Sensitivity retained. The original update and test assessments are unchanged."
        )
      })
    )
    output$preview_card <- shiny::renderUI({
      p <- staged()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        form_draft_notice(source()),
        sensitivity_details_ui(p$fit),
        lapply(
          intersect(c("estimate", "probability"), p$fit$quantities),
          function(q) {
            shiny::plotOutput(
              session$ns(paste0("preview_", q)),
              height = "430px"
            )
          }
        ),
        shiny::actionButton(
          session$ns("retain"),
          "Retain this sensitivity analysis"
        )
      )
    })
    for (quantity in c("estimate", "probability")) {
      local({
        q <- quantity
        output[[paste0("preview_", q)]] <- shiny::renderPlot(
          {
            p <- staged()
            shiny::req(p, q %in% p$fit$quantities)
            print(plot_sensitivity(p$fit, q))
          },
          alt = shiny::reactive(paste(staged()$fit$followup, collapse = " "))
        )
      })
    }
    output$retained <- shiny::renderUI({
      lapply(current()$sensitivities, function(entry) {
        s <- entry$result
        key <- paste0("retained_", substr(entry$id, 1, 16))
        for (quantity in intersect(
          c("estimate", "probability"),
          s$quantities
        )) {
          local({
            fit <- s
            q <- quantity
            output[[paste0(key, "_", q)]] <- shiny::renderPlot(
              print(plot_sensitivity(fit, q)),
              alt = paste(fit$followup, collapse = " ")
            )
          })
        }
        shiny::tags$details(
          shiny::tags$summary(paste(
            "Sensitivity:",
            entry$reason,
            "(revision",
            paste0(s$revision, ")")
          )),
          form_draft_notice(entry$form_draft),
          sensitivity_details_ui(s),
          lapply(
            intersect(c("estimate", "probability"), s$quantities),
            function(q) {
              shiny::plotOutput(
                session$ns(paste0(key, "_", q)),
                height = "430px"
              )
            }
          )
        )
      })
    })
    # A retained finding can be drafted in chat without sending it automatically.
    shiny::observeEvent(
      input$followup,
      safely({
        guard()
        entries <- current()$sensitivities
        if (!length(entries)) {
          abort_suppose("Retain a sensitivity analysis first.")
        }
        fit <- utils::tail(entries, 1)[[1]]$result
        followup(paste(
          "Review this retained sensitivity analysis",
          fit$id,
          "for update",
          fit$update_id,
          paste(fit$followup, collapse = " "),
          "Help me review the assumptions before proposing a model revision."
        ))
      })
    )
    output$status <- shiny::renderText(status())
    list(
      staged = staged,
      status = status,
      source = source,
      incoming = incoming,
      restore = function(d) safely(apply_chat_draft(d)),
      form_state = shiny::reactive(list(
        values = form_values(),
        version = object_id(list(values = form_values(), reason = input$reason))
      ))
    )
  })
}


sensitivity_check_label <- function(status) {
  switch(
    status,
    prior_data_conflict = "prior and observations conflict",
    model_mismatch = "measurement variation mismatch",
    insufficient_data = "too few measurements to check",
    not_flagged = "no mismatch flagged",
    status
  )
}
