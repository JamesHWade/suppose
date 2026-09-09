regression_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Fit and compare models"),
    shiny::tags$p(
      "Review a regression prior, fit observations with unknown measurement noise, and inspect what changes when a predictor is added. Chat can prepare these controls."
    ),
    shiny::tags$details(
      shiny::tags$summary("Attach predictor measurements"),
      shiny::tags$p(
        "First retain outcomes under Measured observations for model updating. Upload predictor columns plus observation_id; IDs must match those outcomes exactly. Predictor measurements have their own source and units."
      ),
      shiny::uiOutput(ns("evidence_selection")),
      shiny::fileInput(
        ns("predictor_csv"),
        "Predictor measurements CSV",
        accept = ".csv"
      ),
      shiny::textInput(
        ns("predictor_units"),
        "Predictor units (name=unit, separated by commas)",
        placeholder = "temperature=degC, duration=minutes"
      ),
      shiny::textInput(ns("predictor_source"), "Predictor source identifier"),
      shiny::actionButton(
        ns("preview_predictors"),
        "Preview predictor attachment"
      ),
      shiny::uiOutput(ns("predictor_preview"))
    ),
    shiny::uiOutput(ns("selection")),
    shiny::uiOutput(ns("model_selection")),
    shiny::uiOutput(ns("incoming")),
    shiny::tags$details(
      shiny::tags$summary("Adjust regression priors"),
      shiny::numericInput(
        ns("location"),
        "Expected outcome at the reference values",
        0
      ),
      shiny::numericInput(
        ns("intercept_sd"),
        "Uncertainty SD for that reference mean",
        10,
        min = 0.000001
      ),
      shiny::numericInput(
        ns("effect_sd"),
        "Effect uncertainty SD per meaningful predictor change",
        5,
        min = 0.000001
      ),
      shiny::numericInput(
        ns("noise_sd"),
        "Prior root expected measurement variance",
        5,
        min = 0.000001
      ),
      shiny::numericInput(
        ns("noise_shape"),
        "Variance prior shape (default 3)",
        3,
        min = 2.000001
      ),
      shiny::numericInput(
        ns("ppc_draws"),
        "Predictive-check replicates (increase for a borderline check)",
        1000,
        min = 200,
        max = 5000,
        step = 200
      ),
      shiny::tags$p(
        "These are new regression assumptions. Initial suggestions may use the current elicited prior, but never realized outcome values. Reference values and meaningful changes use predictor midranges and half-ranges. The R API also accepts explicit transformations."
      )
    ),
    shiny::actionButton(ns("preview"), "Preview regression priors"),
    shiny::uiOutput(ns("prior_card")),
    shiny::uiOutput(ns("result_card")),
    shiny::tags$div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    ),
    shiny::uiOutput(ns("retained"))
  )
}

regression_prior_details <- function(spec) {
  shiny::tagList(
    shiny::tags$h4("New regression assumptions to review"),
    shiny::tags$p(sprintf(
      "At the reference values: expected outcome %.3g %s, marginal prior SD %.3g. Each coefficient starts at zero with marginal SD %.3g per meaningful change. Prior root expected measurement variance: %.3g %s; inverse-gamma shape %.3g.",
      spec$settings$location,
      spec$units,
      spec$settings$intercept_sd,
      spec$settings$effect_sd,
      spec$settings$noise_sd,
      spec$units,
      spec$settings$noise_shape
    )),
    shiny::tags$ul(lapply(spec$transforms, function(t) {
      shiny::tags$li(sprintf(
        "%s: reference %.3g %s; meaningful change %.3g %s.",
        t$name,
        t$center,
        t$units,
        t$scale,
        t$units
      ))
    })),
    if (length(spec$prior_changes)) {
      shiny::tagList(
        shiny::tags$h4("What these priors imply about change"),
        shiny::tags$ul(lapply(spec$prior_changes, function(d) {
          shiny::tags$li(sprintf(
            "%s, %.3g to %.3g %s: central 90%% prior interval for the mean change is %.3g to %.3g %s.",
            d$predictor,
            d$from,
            d$to,
            d$predictor_units,
            d$lower,
            d$upper,
            d$units
          ))
        })),
        shiny::tags$p(
          "Other predictors held fixed; excludes new-measurement noise. These zero-centered effect priors do not reproduce earlier two-mean judgments. Check that scientifically useful changes remain plausible before fitting."
        )
      )
    },
    shiny::tags$p(paste(
      "Baseline:",
      spec$predictors[1],
      if (length(spec$predictors) == 2L) {
        paste("; extended model adds", spec$predictors[2])
      } else {
        ""
      }
    )),
    shiny::tags$details(
      shiny::tags$summary("Full assumptions and references"),
      shiny::tags$ul(lapply(spec$assumptions, shiny::tags$li)),
      inquiry_field("Predictor dataset", spec$design_id),
      inquiry_field("Outcome evidence", spec$evidence_id),
      inquiry_field("Claim revision", spec$revision)
    )
  )
}

regression_result_details <- function(result) {
  shiny::tagList(
    shiny::tags$h4("Posterior results and model criticism"),
    shiny::tags$p(
      "Exact Bayesian regression with unknown common noise. No sampling convergence checks are required. Predictive discrepancy checks use reproducible joint simulations."
    ),
    lapply(result$fits, function(f) {
      shiny::tagList(
        shiny::tags$h5(paste(
          f$label,
          "\u2014",
          paste(f$terms[-1], collapse = " + ")
        )),
        shiny::tags$p(sprintf(
          "Measurement noise SD: median %.3g %s; central 90%% interval %.3g to %.3g. Leave-one-out log predictive score: %.2f.",
          f$noise$median,
          result$spec$units,
          f$noise$lower,
          f$noise$upper,
          f$elpd
        )),
        shiny::tags$table(
          class = "table table-sm",
          shiny::tags$caption(
            "Coefficient means and central 90% intervals; effects are per recorded meaningful change"
          ),
          shiny::tags$thead(shiny::tags$tr(lapply(
            c("Term", "Mean", "Lower", "Upper"),
            shiny::tags$th
          ))),
          shiny::tags$tbody(lapply(f$coefficients, function(c) {
            shiny::tags$tr(
              shiny::tags$td(c$term),
              shiny::tags$td(sprintf("%.3g", c$mean)),
              shiny::tags$td(sprintf("%.3g", c$lower)),
              shiny::tags$td(sprintf("%.3g", c$upper))
            )
          }))
        ),
        shiny::tags$table(
          class = "table table-sm",
          shiny::tags$caption(
            "Posterior predictive checks; fitted data are reused"
          ),
          shiny::tags$thead(shiny::tags$tr(lapply(
            c(
              "Check",
              "Replicated \u2265 observed",
              "Simulation 95% interval",
              "Review"
            ),
            shiny::tags$th
          ))),
          shiny::tags$tbody(lapply(f$checks, function(c) {
            shiny::tags$tr(
              shiny::tags$td(gsub("_", " ", c$statistic)),
              shiny::tags$td(sprintf("%.1f%%", 100 * c$tail_area)),
              shiny::tags$td(
                if (is.null(c$mc_interval)) {
                  "Not recorded"
                } else {
                  sprintf(
                    "%.1f\u2013%.1f%%",
                    100 * c$mc_interval[1],
                    100 * c$mc_interval[2]
                  )
                }
              ),
              shiny::tags$td(
                if (c$status == "review_mismatch") {
                  "Review mismatch"
                } else if (c$status == "simulation_uncertain") {
                  "Borderline; increase replicates"
                } else {
                  "No flag"
                }
              )
            )
          }))
        )
      )
    }),
    shiny::tags$p(sprintf(
      "Checks use %d joint replicates (seed %d); tail-area resolution %.3g. The simulation interval describes Monte Carlo uncertainty in the tail area. Checks near the 2.5%% or 97.5%% screening boundaries remain borderline. No flag does not establish adequate fit; these are not probabilities that a model is true.",
      result$draws,
      result$seed,
      1 / result$draws
    )),
    if (!is.null(result$comparison)) {
      shiny::tagList(
        shiny::tags$h4("Does the added predictor improve prediction?"),
        shiny::tags$p(sprintf(
          "Extended minus baseline leave-one-out log predictive score: %.2f; approximate paired standard error %.2f. Positive favors the extended model.",
          result$comparison$extended_minus_baseline,
          result$comparison$paired_se
        )),
        shiny::tags$p(result$comparison$interpretation)
      )
    },
    shiny::tags$p(
      "These results can motivate another revision or retaining neither model. Earlier models and frozen prospective tests keep their original meaning."
    )
  )
}

regression_server <- function(
  id,
  current,
  guard,
  draft = function() NULL,
  author = function() "You",
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    prior <- shiny::reactiveVal(NULL)
    result <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    predictor_preview <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Attach predictor measurements, then ask chat to prepare a regression or preview the starting priors."
    )
    initialized <- FALSE
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        prior(NULL)
        result(NULL)
        source(NULL)
        incoming(NULL)
        predictor_preview(NULL)
        initialized <<- FALSE
      },
      ignoreInit = TRUE,
      ignoreNULL = FALSE
    )
    shiny::observe({
      if (!initialized && length(current()$predictors)) {
        defaults <- regression_form_defaults(current())
        for (name in c(
          "location",
          "intercept_sd",
          "effect_sd",
          "noise_sd",
          "noise_shape"
        )) {
          shiny::updateNumericInput(session, name, value = defaults[[name]])
        }
        initialized <<- TRUE
      }
    })
    output$evidence_selection <- shiny::renderUI({
      entries <- current()$observations
      if (!length(entries)) {
        return(shiny::tags$p("Attach outcome observations first."))
      }
      choices <- stats::setNames(
        vapply(entries, `[[`, character(1), "id"),
        vapply(
          entries,
          function(e) paste(e$data$source, "revision", e$revision, e$data$role),
          character(1)
        )
      )
      shiny::selectInput(
        session$ns("evidence_id"),
        "Outcome evidence to link",
        choices
      )
    })
    shiny::observeEvent(
      input$preview_predictors,
      safely({
        guard()
        shiny::req(input$predictor_csv)
        tokens <- trimws(strsplit(
          input$predictor_units %||% "",
          ",",
          fixed = TRUE
        )[[1]])
        parts <- strsplit(tokens, "=", fixed = TRUE)
        if (!length(parts) || any(lengths(parts) != 2L)) {
          abort_suppose("Specify each predictor unit as name=unit.")
        }
        units <- stats::setNames(
          vapply(parts, function(p) trimws(p[2]), character(1)),
          vapply(parts, function(p) trimws(p[1]), character(1))
        )
        predictor_preview(regression_predictors(
          current(),
          input$evidence_id,
          input$predictor_csv$datapath,
          units,
          input$predictor_source,
          author()
        ))
        status("Review the linked predictor measurements before attaching.")
      })
    )
    output$predictor_preview <- shiny::renderUI({
      d <- predictor_preview()
      if (is.null(d)) {
        return(NULL)
      }
      shiny::tagList(
        shiny::tags$p(paste(
          length(d$rows),
          "matched measurements from",
          d$source
        )),
        shiny::tags$ul(lapply(names(d$units), function(n) {
          shiny::tags$li(paste(n, "in", d$units[[n]]))
        })),
        shiny::actionButton(
          session$ns("attach_predictors"),
          "Attach reviewed predictors"
        )
      )
    })
    shiny::observeEvent(
      input$attach_predictors,
      safely({
        guard()
        shiny::req(predictor_preview())
        current(record_predictors(current(), predictor_preview()))
        predictor_preview(NULL)
        prior(NULL)
        result(NULL)
        status(
          "Predictor measurements retained. Prepare and review the regression priors next."
        )
      })
    )
    output$selection <- shiny::renderUI({
      designs <- current()$predictors
      if (!length(designs)) {
        return(shiny::tags$p("No predictor dataset is attached yet."))
      }
      choices <- stats::setNames(
        vapply(designs, `[[`, character(1), "id"),
        vapply(
          designs,
          function(d) paste(d$source, paste(names(d$units), collapse = ", ")),
          character(1)
        )
      )
      selected <- shiny::isolate(input$design_id)
      if (!isTRUE(selected %in% unname(choices))) {
        selected <- utils::tail(unname(choices), 1)
      }
      shiny::selectInput(
        session$ns("design_id"),
        "Predictor dataset",
        choices,
        selected = selected
      )
    })
    # Separate rendering keeps changing a model from resetting its dataset.
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
    output$model_selection <- shiny::renderUI({
      designs <- current()$predictors
      if (!length(designs)) {
        return(NULL)
      }
      d <- Filter(function(d) identical(d$id, input$design_id), designs)
      if (!length(d)) {
        d <- utils::tail(designs, 1)
      }
      names <- names(d[[1]]$units)
      baseline <- shiny::isolate(input$baseline)
      added <- shiny::isolate(input$added)
      defaults <- regression_form_defaults(current())
      if (identical(defaults$design_id, d[[1]]$id)) {
        baseline <- baseline %||% defaults$predictors[1]
        added <- added %||%
          if (length(defaults$predictors) > 1L) defaults$predictors[2] else ""
      }
      saved <- source()
      if (!is.null(saved) && identical(saved$values$design_id, d[[1]]$id)) {
        baseline <- saved$values$predictors[1]
        added <- if (length(saved$values$predictors) > 1L) {
          saved$values$predictors[2]
        } else {
          ""
        }
      }
      if (!isTRUE(baseline %in% names)) {
        baseline <- names[1]
      }
      if (!isTRUE(added %in% names)) {
        added <- ""
      }
      shiny::tagList(
        shiny::selectInput(
          session$ns("baseline"),
          "Baseline predictor",
          names,
          selected = baseline
        ),
        shiny::selectInput(
          session$ns("added"),
          "Predictor to add for comparison",
          c("None yet" = "", stats::setNames(names, names)),
          selected = added
        )
      )
    })
    values <- shiny::reactive({
      if (!length(current()$predictors)) {
        return(list())
      }
      defaults <- regression_form_defaults(current())
      chosen <- c(
        input$baseline %||% defaults$predictors,
        if (nzchar(input$added %||% "")) input$added
      )
      list(
        design_id = input$design_id %||% defaults$design_id,
        predictors = chosen,
        location = input$location %||% defaults$location,
        intercept_sd = input$intercept_sd %||% defaults$intercept_sd,
        effect_sd = input$effect_sd %||% defaults$effect_sd,
        noise_sd = input$noise_sd %||% defaults$noise_sd,
        noise_shape = input$noise_shape %||% defaults$noise_shape
      )
    })
    form_state <- shiny::reactive(list(
      values = values(),
      version = object_id(values())
    ))
    restore_settings <- function() {
      v <- regression_form_defaults(current())
      d <- Filter(
        function(d) identical(d$id, v$design_id),
        current()$predictors
      )[[1]]
      choices <- names(d$units)
      shiny::updateSelectInput(session, "design_id", selected = v$design_id)
      shiny::updateSelectInput(
        session,
        "baseline",
        choices = choices,
        selected = v$predictors[1]
      )
      shiny::updateSelectInput(
        session,
        "added",
        choices = c("None yet" = "", stats::setNames(choices, choices)),
        selected = if (length(v$predictors) > 1L) v$predictors[2] else ""
      )
      for (name in c(
        "location",
        "intercept_sd",
        "effect_sd",
        "noise_sd",
        "noise_shape"
      )) {
        shiny::updateNumericInput(session, name, value = v[[name]])
      }
      prior(NULL)
      result(NULL)
      source(NULL)
      incoming(NULL)
      status(
        "Reviewed model settings are ready to continue. Preview its priors before fitting another revision."
      )
    }
    apply_draft <- function(d) {
      check_seal(d, "suppose_form_draft")
      if (!identical(d$base_id, proposal_basis_id(current()))) {
        abort_suppose(
          "This draft belongs to an earlier record. Ask chat to refresh it.",
          "stale"
        )
      }
      preview <- workbench_form_preview(current(), "regression", d$values)
      v <- preview$values
      shiny::updateSelectInput(session, "design_id", selected = v$design_id)
      design <- Filter(
        function(d) identical(d$id, v$design_id),
        current()$predictors
      )[[1]]
      names <- names(design$units)
      shiny::updateSelectInput(
        session,
        "baseline",
        choices = names,
        selected = v$predictors[1]
      )
      shiny::updateSelectInput(
        session,
        "added",
        choices = c("None yet" = "", stats::setNames(names, names)),
        selected = if (length(v$predictors) > 1L) v$predictors[2] else ""
      )
      for (name in c(
        "location",
        "intercept_sd",
        "effect_sd",
        "noise_sd",
        "noise_shape"
      )) {
        shiny::updateNumericInput(session, name, value = v[[name]])
      }
      prior(list(spec = preview$fit, values = v))
      result(NULL)
      source(d)
      incoming(NULL)
      status(
        "Chat filled the model form and prepared prior predictions. Review the assumptions and independence setting before fitting."
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
            "You edited the form while chat worked. Your edits are kept; choose whether to use the incoming draft."
          )
        } else {
          apply_draft(d)
        }
      })
    )
    shiny::observeEvent(
      input$use_chat_draft,
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
        p <- workbench_form_preview(current(), "regression", values())
        prior(list(spec = p$fit, values = p$values))
        result(NULL)
        if (
          !is.null(source()) && !identical(source()$base_id, p$fit$basis_id)
        ) {
          source(NULL)
        }
        status(
          "Review the new prior assumptions and predictive intervals before fitting."
        )
      })
    )
    output$prior_card <- shiny::renderUI({
      p <- prior()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        form_draft_notice(source()),
        regression_prior_details(p$spec),
        shiny::plotOutput(session$ns("prior_plot"), height = "500px"),
        shiny::checkboxInput(
          session$ns("independent"),
          "These rows are independent measurement units",
          shiny::isolate(input$independent) %||%
            any(vapply(
              current()$regressions,
              function(e) {
                identical(e$result$spec$evidence_id, p$spec$evidence_id) &&
                  isTRUE(e$result$independent)
              },
              logical(1)
            ))
        ),
        shiny::actionButton(
          session$ns("fit"),
          "Fit reviewed priors and check predictions"
        )
      )
    })
    output$prior_plot <- shiny::renderPlot(
      {
        shiny::req(prior())
        print(regression_app_plot(prior()$spec))
      },
      alt = "Prior mean and outcome intervals at the recorded predictor values. These new assumptions have not yet been fitted."
    )
    shiny::observeEvent(
      input$fit,
      safely({
        guard()
        shiny::req(prior())
        if (!identical(object_id(values()), object_id(prior()$values))) {
          abort_suppose(
            "Settings changed. Preview priors again before fitting.",
            "stale"
          )
        }
        result(fit_regression(
          current(),
          prior()$spec,
          independent = input$independent,
          reviewed = TRUE,
          draws = input$ppc_draws %||% 1000
        ))
        status(
          "Fits and checks are ready. Review the predictive discrepancies and comparison, then retain your choice."
        )
      })
    )
    output$result_card <- shiny::renderUI({
      r <- result()
      if (is.null(r)) {
        return(NULL)
      }
      shiny::tagList(
        regression_result_details(r),
        shiny::plotOutput(session$ns("prediction_plot"), height = "500px"),
        shiny::plotOutput(session$ns("residual_plot"), height = "500px"),
        shiny::tags$details(
          shiny::tags$summary("Inspect joint predictive simulations"),
          shiny::plotOutput(session$ns("checks_plot"), height = "900px")
        ),
        if (!is.null(r$comparison)) {
          shiny::plotOutput(session$ns("comparison_plot"), height = "350px")
        },
        shiny::radioButtons(
          session$ns("choice"),
          "Which model should be retained for this review?",
          c(
            stats::setNames(
              vapply(r$fits, `[[`, character(1), "label"),
              vapply(r$fits, `[[`, character(1), "label")
            ),
            "Neither is adequate" = "neither"
          ),
          selected = if (length(r$fits) == 1L) "baseline" else "neither"
        ),
        shiny::textAreaInput(
          session$ns("reason"),
          "Reason for the choice and remaining limitations",
          value = source()$reason %||% ""
        ),
        shiny::actionButton(
          session$ns("retain"),
          "Retain reviewed model choice"
        )
      )
    })
    for (view in c("prediction", "residuals", "checks", "comparison")) {
      local({
        v <- view
        name <- if (v == "residuals") "residual_plot" else paste0(v, "_plot")
        output[[name]] <- shiny::renderPlot(
          {
            shiny::req(result())
            print(regression_app_plot(result(), v))
          },
          alt = paste(
            "Regression",
            v,
            "view. Numeric results and model-check explanations appear above."
          )
        )
      })
    }
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        shiny::req(result())
        if (!isTRUE(result()$draws == (input$ppc_draws %||% 1000))) {
          abort_suppose(
            "Predictive-check settings changed. Fit again before retaining.",
            "stale"
          )
        }
        if (!identical(object_id(values()), object_id(prior()$values))) {
          abort_suppose(
            "Model settings changed. Preview and fit again before retaining.",
            "stale"
          )
        }
        current(record_regression(
          current(),
          result(),
          input$choice,
          author(),
          input$reason,
          reviewed = TRUE,
          form_draft = source()
        ))
        prior(NULL)
        result(NULL)
        source(NULL)
        retained()
        status(
          "Reviewed model choice retained with both fits and their checks. Earlier scientific history is unchanged."
        )
      })
    )
    output$retained <- shiny::renderUI(lapply(
      current()$regressions,
      function(e) {
        key <- paste0("saved_", substr(e$id, 1, 12))
        output[[key]] <- shiny::renderPlot(
          print(regression_app_plot(e$result, "residuals")),
          alt = "Retained residual patterns for the reviewed models."
        )
        shiny::tags$details(
          shiny::tags$summary(paste(
            "Reviewed regression:",
            e$choice,
            "\u2014",
            e$reason
          )),
          inquiry_field("Reviewed by", e$author),
          form_draft_notice(e$form_draft),
          regression_prior_details(e$result$spec),
          regression_result_details(e$result),
          shiny::plotOutput(session$ns(key), height = "500px")
        )
      }
    ))
    output$status <- shiny::renderText(status())
    list(
      prior = prior,
      result = result,
      source = source,
      incoming = incoming,
      status = status,
      form_state = form_state,
      restore_settings = function() safely(restore_settings()),
      restore = function(d) safely(apply_draft(d))
    )
  })
}

regression_app_plot <- function(
  x,
  view = if (identical(x$type, "suppose_regression_spec")) {
    "prior"
  } else {
    "prediction"
  }
) {
  plot <- plot_regression(x, view)
  widths <- c(title = 35, subtitle = 45, caption = 48, x = 40, y = 28)
  labels <- lapply(names(widths), function(name) {
    text <- plot$labels[[name]]
    if (is.null(text)) {
      return(NULL)
    }
    paste(strwrap(text, width = widths[[name]]), collapse = "\n")
  })
  plot + do.call(ggplot2::labs, stats::setNames(labels, names(widths)))
}
