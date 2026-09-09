research_design_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Plan the next measurement"),
    shiny::tags$p(
      "Compare exact expected learning or decision benefits. Chat can prepare settings for review. Each row is an alternative experiment; saving a choice does not execute or freeze a test."
    ),
    shiny::uiOutput(ns("saved_plans")),
    shiny::uiOutput(ns("model")),
    shiny::tags$details(
      id = ns("settings"),
      shiny::tags$summary("Adjust candidate settings and assumptions"),
      shiny::selectInput(
        ns("purpose"),
        "Research purpose",
        c(
          "Estimate a mean difference" = "estimate",
          "Choose between two protocols" = "decide"
        )
      ),
      shiny::textAreaInput(
        ns("contrast_csv"),
        "Protocols A and B: two rows in original predictor units",
        width = "100%"
      ),
      shiny::textAreaInput(
        ns("candidates_csv"),
        "Candidate experiments: candidate_id, predictors, repeats, cost, feasible",
        width = "100%",
        height = "170px"
      ),
      shiny::numericInput(
        ns("max_units"),
        "Available independent measurement units",
        6,
        min = 1,
        max = 100
      ),
      shiny::numericInput(
        ns("threshold"),
        "Required mean gain to choose B (zero for estimation)",
        0
      ),
      shiny::textAreaInput(
        ns("preference"),
        "Decision preference and its meaning",
        width = "100%"
      ),
      shiny::textAreaInput(
        ns("rationale"),
        "Research purpose, protocol, feasibility and cost assumptions",
        width = "100%"
      ),
      shiny::tags$p(
        "Experiment cost is a total in the selected loss units: squared outcome units for estimation, outcome-equivalent utility for decisions. Zero explicitly omits experiment costs. Money cannot be subtracted without a stated conversion."
      ),
    ),
    shiny::actionButton(ns("preview"), "Compare candidate experiments"),
    shiny::uiOutput(ns("incoming")),
    shiny::uiOutput(ns("preview_card")),
    shiny::textOutput(ns("status")),
    shiny::uiOutput(ns("retained"))
  )
}

research_design_details <- function(d) {
  shiny::tagList(
    shiny::tags$h4(
      if (d$purpose == "estimate") {
        "Expected reduction in mean-difference uncertainty"
      } else {
        "Expected improvement in the protocol decision"
      }
    ),
    shiny::tags$p(sprintf(
      "Current expected loss: %.5g %s. Exact calculation integrates unknown common noise; no Monte Carlo error.",
      d$current_loss,
      d$loss_units
    )),
    shiny::tags$p(sprintf(
      "Target: protocol B minus A. Current mean difference %.4g %s; decision threshold %.4g. Budget: %d independent units per alternative.",
      d$current$contrast_mean,
      d$units,
      d$threshold,
      d$max_units
    )),
    inquiry_field(
      "Protocol A",
      paste(
        names(d$target[[1]]),
        unlist(d$target[[1]]),
        unlist(d$predictor_units),
        collapse = "; "
      )
    ),
    inquiry_field(
      "Protocol B",
      paste(
        names(d$target[[2]]),
        unlist(d$target[[2]]),
        unlist(d$predictor_units),
        collapse = "; "
      )
    ),
    if (!is.null(d$source_plan_id)) {
      inquiry_field("Continues reviewed plan", d$source_plan_id)
    },
    inquiry_field("Preference", d$preference),
    inquiry_field("Research assumptions", d$rationale),
    shiny::tags$div(
      class = "table-responsive",
      role = "region",
      tabindex = "0",
      `aria-label` = "Candidate experiment comparison",
      shiny::tags$table(
        class = "table table-sm",
        shiny::tags$caption(paste(
          "Candidate benefit and cost in",
          d$loss_units
        )),
        shiny::tags$thead(shiny::tags$tr(lapply(
          c(
            "Candidate / setting",
            "Units",
            "Eligible",
            "Benefit",
            "Cost",
            "Net"
          ),
          shiny::tags$th
        ))),
        shiny::tags$tbody(lapply(d$candidates, function(r) {
          shiny::tags$tr(
            shiny::tags$td(paste(
              r$candidate_id,
              paste(
                names(r$predictors),
                unlist(r$predictors),
                sep = "=",
                collapse = ", "
              ),
              if (r$outside_observed_range) "(outside observed range)"
            )),
            shiny::tags$td(r$repeats),
            shiny::tags$td(if (r$eligible) "Yes" else "No"),
            shiny::tags$td(sprintf("%.5g", r$benefit)),
            shiny::tags$td(sprintf("%.5g", r$cost)),
            shiny::tags$td(sprintf("%.5g", r$net_benefit))
          )
        }))
      )
    ),
    shiny::tags$p(
      if (length(d$recommended)) {
        paste(
          "Highest positive net benefit:",
          paste(d$recommended, collapse = ", ")
        )
      } else {
        d$no_design_reason
      }
    ),
    shiny::tags$h5("Model limitations still matter"),
    inquiry_field("Retained model review", d$model_review_reason),
    shiny::tags$ul(lapply(
      Filter(function(c) c$status != "not_flagged", d$model_checks),
      function(c) {
        shiny::tags$li(paste(
          c$statistic,
          c$status,
          sprintf("(tail area %.4g)", c$tail_area)
        ))
      }
    )),
    if (d$target_outside_observed_range) {
      shiny::tags$p(
        "The target includes settings outside observed predictor ranges."
      )
    },
    shiny::tags$details(
      shiny::tags$summary("Assumptions and numerical provenance"),
      shiny::tags$ul(lapply(d$assumptions, shiny::tags$li)),
      inquiry_field("Engine", unlist(d$engine)),
      inquiry_field("Reviewed regression", d$regression_id)
    )
  )
}

research_design_server <- function(
  id,
  current,
  guard,
  draft = function() NULL,
  author = function() "You",
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    preview <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    resumed <- shiny::reactiveVal(NULL)
    pending_plan <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Retain a model, then ask chat to prepare next-measurement options."
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    output$model <- shiny::renderUI({
      entries <- Filter(
        function(e) e$choice != "neither",
        current()$regressions
      )
      shiny::selectInput(
        session$ns("regression_id"),
        "Reviewed model",
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
    values <- shiny::reactive({
      if (
        !length(Filter(
          function(e) e$choice != "neither",
          current()$regressions
        ))
      ) {
        return(list())
      }
      v <- research_design_defaults(current())
      for (name in names(v)) {
        v[name] <- list(
          if (name == "source_plan_id") {
            resumed()
          } else {
            input[[name]] %||% v[[name]]
          }
        )
      }
      v
    })
    form_state <- shiny::reactive(list(
      values = values(),
      version = object_id(values())
    ))
    update <- function(v) {
      resumed(v$source_plan_id)
      shiny::updateSelectInput(
        session,
        "regression_id",
        selected = v$regression_id
      )
      shiny::updateSelectInput(session, "purpose", selected = v$purpose)
      for (name in c("threshold", "max_units")) {
        shiny::updateNumericInput(session, name, value = v[[name]])
      }
      for (name in c(
        "candidates_csv",
        "contrast_csv",
        "preference",
        "rationale"
      )) {
        shiny::updateTextAreaInput(session, name, value = v[[name]])
      }
    }
    output$saved_plans <- shiny::renderUI({
      plans <- current()$research_designs
      if (!length(plans)) {
        return(NULL)
      }
      shiny::tagList(
        shiny::selectInput(
          session$ns("plan_id"),
          "Reviewed plan to continue",
          stats::setNames(
            vapply(plans, `[[`, character(1), "id"),
            vapply(plans, function(e) paste(e$choice, e$reason), character(1))
          )
        ),
        shiny::actionButton(
          session$ns("resume_plan"),
          "Start draft from reviewed plan"
        ),
        shiny::actionButton(session$ns("blank_plan"), "Start a blank plan"),
        if (!is.null(pending_plan())) {
          shiny::actionButton(
            session$ns("replace_plan"),
            "Replace current form with reviewed plan"
          )
        }
      )
    })
    resume_plan <- function(id) {
      v <- research_plan_form_values(current(), id)
      update(v)
      preview(NULL)
      source(NULL)
      incoming(NULL)
      pending_plan(NULL)
      shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
      status(
        "Reviewed settings restored as a new draft. Compare candidates again before a fresh review; the original plan is unchanged."
      )
    }
    shiny::observeEvent(
      input$resume_plan,
      safely({
        guard()
        if (nzchar(values()$candidates_csv %||% "")) {
          pending_plan(input$plan_id)
          status(
            "Current form edits are preserved. Choose Replace current form with reviewed plan to use the saved settings."
          )
        } else {
          resume_plan(input$plan_id)
        }
      })
    )
    shiny::observeEvent(
      input$replace_plan,
      safely({
        guard()
        shiny::req(pending_plan())
        resume_plan(pending_plan())
      })
    )
    shiny::observeEvent(
      input$blank_plan,
      safely({
        guard()
        update(research_design_defaults(current()))
        preview(NULL)
        source(NULL)
        incoming(NULL)
        pending_plan(NULL)
        status("New blank plan. Earlier reviews are unchanged.")
      })
    )
    apply_draft <- function(d) {
      check_seal(d, "suppose_form_draft")
      if (!identical(d$base_id, proposal_basis_id(current()))) {
        abort_suppose(
          "Refresh this design draft against the current record.",
          "stale"
        )
      }
      p <- workbench_form_preview(current(), "design", d$values)
      update(p$values)
      preview(p)
      source(d)
      incoming(NULL)
      shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
      status(
        "Suggested design is ready. Review targets, independent replication, feasibility, preferences, costs and model limitations."
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
            "Your form edits are preserved. Choose whether to use the incoming chat draft."
          )
        } else {
          apply_draft(d)
        }
      })
    )
    output$incoming <- shiny::renderUI({
      if (!is.null(incoming())) {
        shiny::actionButton(session$ns("use_chat"), "Use chat design draft")
      }
    })
    shiny::observeEvent(
      input$use_chat,
      safely({
        guard()
        shiny::req(incoming())
        apply_draft(incoming())
      })
    )
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        preview(workbench_form_preview(current(), "design", values()))
        if (
          !is.null(source()) &&
            !identical(source()$base_id, preview()$fit$basis_id)
        ) {
          source(NULL)
        }
        status(
          "Compare expected benefits and review the assumptions before retaining a planning choice."
        )
      })
    )
    output$preview_card <- shiny::renderUI({
      shiny::req(preview())
      d <- preview()$fit
      ids <- vapply(
        Filter(function(r) r$eligible, d$candidates),
        `[[`,
        character(1),
        "candidate_id"
      )
      shiny::tagList(
        form_draft_notice(source()),
        research_design_details(d),
        shiny::selectInput(
          session$ns("choice"),
          "Planning choice",
          c("None for now" = "none", stats::setNames(ids, ids))
        ),
        shiny::checkboxInput(
          session$ns("reviewed"),
          "I reviewed candidate feasibility, independent replicates, costs, preferences and model limitations",
          FALSE
        ),
        shiny::textAreaInput(
          session$ns("reason"),
          "Reason for the planning choice and remaining limitations",
          width = "100%"
        ),
        shiny::actionButton(
          session$ns("retain"),
          "Retain research planning choice"
        )
      )
    })
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        shiny::req(preview())
        if (!identical(object_id(values()), object_id(preview()$values))) {
          abort_suppose(
            "Design settings changed. Compare candidates again before retaining.",
            "stale"
          )
        }
        current(record_research_design(
          current(),
          preview()$fit,
          input$choice,
          author(),
          input$reason,
          input$reviewed,
          source()
        ))
        preview(NULL)
        source(NULL)
        incoming(NULL)
        retained()
        status(
          "Research planning choice retained. No experiment was executed and no prospective test was frozen."
        )
      })
    )
    output$retained <- shiny::renderUI(lapply(
      current()$research_designs,
      function(e) {
        shiny::tags$details(
          shiny::tags$summary(paste(
            "Reviewed research plan:",
            e$choice,
            "\u2014",
            e$reason
          )),
          inquiry_field("Reviewer", e$author),
          form_draft_notice(e$form_draft),
          research_design_details(e$design)
        )
      }
    ))
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        preview(NULL)
        source(NULL)
        incoming(NULL)
      },
      ignoreInit = TRUE
    )
    output$status <- shiny::renderText(status())
    list(
      resume_plan = resume_plan,
      preview = preview,
      source = source,
      incoming = incoming,
      status = status,
      form_state = form_state,
      restore = function(d) safely(apply_draft(d))
    )
  })
}
