extension_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Review a model extension"),
    shiny::tags$p(
      "Describe the predictor in chat and ask to prepare this form, or start here. The comparison uses the current prior and keeps it intact."
    ),
    shiny::uiOutput(ns("incoming")),
    shiny::textInput(ns("predictor"), "Predictor to add", "Added predictor"),
    shiny::tags$details(
      shiny::tags$summary("Adjust starting assumptions"),
      shiny::textInput(ns("predictor_units"), "Predictor units", "units"),
      shiny::numericInput(
        ns("center"),
        "Reference value (added effect is zero here)",
        0
      ),
      shiny::numericInput(
        ns("scale"),
        "A meaningful change in this predictor",
        1,
        min = 0.000001
      ),
      shiny::numericInput(
        ns("effect_mean"),
        "Expected effect per meaningful change",
        0
      ),
      shiny::textInput(
        ns("effect_sd"),
        "Effect uncertainty SD (blank uses a starting spread from the current prior)",
        ""
      ),
      shiny::textInput(
        ns("plausible_lower"),
        "Optional lower plausible outcome",
        ""
      ),
      shiny::textInput(
        ns("plausible_upper"),
        "Optional upper plausible outcome",
        ""
      ),
      shiny::textInput(
        ns("reason"),
        "Reason to consider the extension",
        "Review how adding a predictor changes expected outcomes"
      )
    ),
    shiny::tags$p(
      "Defaults when unspecified: zero expected added effect and a spread derived from existing mean uncertainty. The coefficient is independent of the original means. Review the current values in the preview below."
    ),
    shiny::actionButton(ns("preview"), "Preview extension"),
    shiny::uiOutput(ns("preview_card")),
    shiny::tags$div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    ),
    shiny::uiOutput(ns("retained"))
  )
}

extension_details_ui <- function(x) {
  s <- x$settings
  summaries <- lapply(c("original", "unscaled", "scaled"), function(model) {
    rows <- Filter(function(r) r$model == model, x$rows)
    data.frame(
      model = switch(
        model,
        original = "Reference",
        unscaled = "Unscaled reuse",
        scaled = "Scaled to meaningful change"
      ),
      widest = max(vapply(
        rows,
        function(r) r$outcome_upper - r$outcome_lower,
        numeric(1)
      )),
      outside = if (is.null(s$plausible_lower) && is.null(s$plausible_upper)) {
        NA_real_
      } else {
        max(vapply(rows, `[[`, numeric(1), "outside_probability"))
      }
    )
  })
  shiny::tagList(
    shiny::tags$h4(paste("Adding", s$predictor)),
    shiny::tags$p(sprintf(
      "Reference: %g %s. Meaningful change: %g %s. Suggested effect prior: normal mean %g, SD %.3g %s per meaningful change.",
      s$center,
      s$predictor_units,
      s$scale,
      s$predictor_units,
      s$effect_mean,
      s$effect_sd,
      x$units
    )),
    shiny::tags$p(
      "The unscaled comparison reuses that numerical coefficient prior per raw predictor unit. The scaled comparison uses it per meaningful change. Neither has been fitted to new observations."
    ),
    shiny::tags$table(
      class = "table table-sm",
      shiny::tags$caption(paste(
        "Widest central 90% outcome interval across the inspected scenarios, in",
        x$units
      )),
      shiny::tags$thead(shiny::tags$tr(
        shiny::tags$th("Model"),
        shiny::tags$th("Width"),
        if (!is.null(s$plausible_lower) || !is.null(s$plausible_upper)) {
          shiny::tags$th("Largest probability outside plausible bounds")
        }
      )),
      shiny::tags$tbody(lapply(summaries, function(r) {
        shiny::tags$tr(
          shiny::tags$td(r$model),
          shiny::tags$td(sprintf("%.3g", r$widest)),
          if (!is.na(r$outside)) {
            shiny::tags$td(sprintf("%.1f%%", 100 * r$outside))
          }
        )
      }))
    ),
    shiny::tags$p(x$matched_contrast$explanation),
    shiny::tags$details(
      shiny::tags$summary("New assumptions to review"),
      shiny::tags$ul(lapply(x$assumptions, shiny::tags$li)),
      inquiry_field("Effect SD source", x$defaults$effect_sd),
      inquiry_field("Original conditions inspected", x$settings$conditions),
      inquiry_field(
        "Added predictor values inspected",
        x$settings$predictor_values
      )
    ),
    shiny::tags$p(
      "Outside the elicited anchors, these comparisons assume a straight-line relationship. Review extrapolated outcomes; the original two judgments did not establish this relationship."
    ),
    shiny::tags$details(
      shiny::tags$summary("Exact model references"),
      inquiry_field("Prior", x$prior_id),
      inquiry_field("Claim", x$claim_id),
      inquiry_field("Comparison", x$id)
    )
  )
}

extension_server <- function(
  id,
  current,
  guard,
  draft = function() NULL,
  author = function() "You",
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    staged <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Preview the defaults, or ask chat to prepare this form."
    )
    lineage <- shiny::reactiveVal(shiny::isolate(
      current()$revisions[[1]]$claim$id
    ))
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    optional_number <- function(x) {
      if (is.null(x) || !nzchar(trimws(x))) {
        return(NULL)
      }
      suppressWarnings(as.numeric(x))
    }
    args <- shiny::reactive(list(
      predictor = input$predictor,
      predictor_units = input$predictor_units,
      center = input$center,
      scale = input$scale,
      effect_mean = input$effect_mean,
      effect_sd = optional_number(input$effect_sd),
      plausible_lower = optional_number(input$plausible_lower),
      plausible_upper = optional_number(input$plausible_upper)
    ))
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        next_id <- current()$revisions[[1]]$claim$id
        if (identical(next_id, lineage())) {
          return()
        }
        lineage(next_id)
        staged(NULL)
        source(NULL)
        incoming(NULL)
      },
      ignoreInit = TRUE,
      ignoreNULL = FALSE
    )
    apply_chat_draft <- function(d) {
      check_seal(d, "suppose_form_draft")
      if (!identical(d$base_id, proposal_basis_id(current()))) {
        status(
          "This chat draft belongs to an earlier record. Ask chat to refresh it."
        )
        return()
      }
      incoming(NULL)
      prepared <- workbench_form_preview(current(), "extension", d$values)
      v <- prepared$values
      for (name in c(
        "predictor",
        "predictor_units",
        "effect_sd",
        "plausible_lower",
        "plausible_upper"
      )) {
        shiny::updateTextInput(session, name, value = v[[name]] %||% "")
      }
      for (name in c("center", "scale", "effect_mean")) {
        shiny::updateNumericInput(session, name, value = v[[name]])
      }
      shiny::updateTextInput(session, "reason", value = d$reason)
      source(d)
      staged(list(comparison = prepared$fit, args = v))
      status(
        "Chat filled the form and prepared this comparison. Review suggested assumptions before retaining it."
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
              object_id(list(values = args(), reason = input$reason))
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
        prepared <- workbench_form_preview(current(), "extension", args())
        staged(list(comparison = prepared$fit, args = prepared$values))
        status(
          "Review the predictions and assumptions, then choose the extension to retain."
        )
      })
    )
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        p <- staged()
        if (is.null(p)) {
          abort_suppose("Preview the extension first.")
        }
        if (!identical(object_id(args()), object_id(p$args))) {
          abort_suppose(
            "The model settings changed. Preview again before retaining.",
            "stale"
          )
        }
        d <- source()
        if (!is.null(d) && !identical(d$base_id, p$comparison$basis_id)) {
          d <- NULL
        }
        current(record_extension(
          current(),
          p$comparison,
          author(),
          input$reason,
          input$choice %||% "scaled",
          reviewed = TRUE,
          form_draft = d
        ))
        staged(NULL)
        source(NULL)
        retained()
        status(
          "Reviewed model alternative retained. Existing priors, fits and frozen tests remain available; fitting this extended model is a separate capability."
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
        extension_details_ui(p$comparison),
        shiny::plotOutput(session$ns("preview_plot"), height = "600px"),
        shiny::radioButtons(
          session$ns("choice"),
          "Which prior should this reviewed alternative use?",
          c(
            "Per meaningful change (scaled)" = "scaled",
            "Per raw unit (unscaled)" = "unscaled"
          ),
          selected = "scaled"
        ),
        shiny::tags$p(
          "Retaining confirms that you reviewed these new assumptions and predictions. It does not validate the model against observations."
        ),
        shiny::actionButton(session$ns("retain"), "Retain reviewed extension")
      )
    })
    output$preview_plot <- shiny::renderPlot(
      {
        shiny::req(staged())
        print(plot_extension(staged()$comparison))
      },
      alt = shiny::reactive(staged()$comparison$matched_contrast$explanation)
    )
    output$retained <- shiny::renderUI(lapply(
      current()$model_extensions,
      function(entry) {
        key <- paste0("saved_", substr(entry$id, 1, 16))
        output[[key]] <- shiny::renderPlot(
          print(plot_extension(entry$comparison)),
          alt = entry$comparison$matched_contrast$explanation
        )
        shiny::tags$details(
          shiny::tags$summary(paste(
            "Reviewed extension:",
            entry$comparison$settings$predictor
          )),
          inquiry_field("Chosen prior", entry$choice),
          inquiry_field("Scientific reason", entry$reason),
          inquiry_field("Reviewed by", entry$author),
          form_draft_notice(entry$form_draft),
          extension_details_ui(entry$comparison),
          shiny::plotOutput(session$ns(key), height = "600px")
        )
      }
    ))
    output$status <- shiny::renderText(status())
    list(
      staged = staged,
      status = status,
      source = source,
      incoming = incoming,
      restore = function(d) safely(apply_chat_draft(d)),
      form_state = shiny::reactive(list(
        values = args(),
        version = object_id(list(values = args(), reason = input$reason))
      ))
    )
  })
}
