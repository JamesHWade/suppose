updates_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    shiny::tags$summary("Learn from measurements"),
    shiny::tags$p(
      "Update the current normal prior using measurements designated for updating. This keeps the original prior and review state intact."
    ),
    shiny::uiOutput(ns("configuration")),
    shiny::checkboxInput(
      ns("independent"),
      "These are independent measurement units",
      FALSE
    ),
    shiny::textInput(ns("reason"), "Why perform this update?"),
    shiny::actionButton(ns("preview"), "Preview update"),
    shiny::tags$div(role = "status", shiny::textOutput(ns("status"))),
    shiny::uiOutput(ns("preview_card")),
    shiny::uiOutput(ns("retained"))
  )
}

update_diagnostics_ui <- function(x) {
  shiny::tagList(
    shiny::tags$p(update_summary_text(x)),
    inquiry_field("Computation", x$diagnostics$method),
    inquiry_field(
      "Prior predictive check",
      x$diagnostics$prior_predictive_conflict$status
    ),
    lapply(x$diagnostics$measurement_variation, function(d) {
      inquiry_field(
        paste("Variation check at condition", d$condition),
        paste(
          d$status,
          if (!is.null(d$tail_area)) sprintf("(tail area %.3g)", d$tail_area)
        )
      )
    }),
    shiny::tags$p(x$diagnostics$interpretation),
    shiny::tags$p(sprintf(
      "%d missing outcomes excluded. Known measurement variation was not estimated from these observations.",
      length(x$excluded)
    ))
  )
}

updates_server <- function(id, current, guard) {
  shiny::moduleServer(id, function(input, output, session) {
    staged <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Map the measurement labels to the prior conditions, then preview."
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    eligible <- shiny::reactive(Filter(
      function(a) {
        a$revision == length(current()$revisions) && a$data$role == "update"
      },
      current()$observations
    ))
    config <- shiny::reactive(list(
      input$evidence,
      input$low,
      input$high,
      input$independent,
      input$reason
    ))
    output$configuration <- shiny::renderUI({
      record <- current()
      prior <- utils::tail(record$revisions, 1)[[1]]$candidate
      if (is.null(prior)) {
        return(shiny::tags$p("Retain a numerical prior before updating it."))
      }
      evidence <- eligible()
      if (!length(evidence)) {
        return(shiny::tags$p(
          "Attach measurements with intended use 'Model update' first."
        ))
      }
      labels <- unique(unlist(lapply(evidence, function(a) {
        vapply(a$data$rows, `[[`, character(1), "condition")
      })))
      shiny::tagList(
        shiny::selectInput(
          session$ns("evidence"),
          "Measurements to include",
          stats::setNames(
            vapply(evidence, `[[`, character(1), "id"),
            vapply(
              evidence,
              function(a) {
                paste(a$data$source, "\u2014", length(a$data$rows), "rows")
              },
              character(1)
            )
          ),
          multiple = TRUE
        ),
        shiny::selectInput(
          session$ns("low"),
          paste("CSV label for", prior$conditions[1], prior$condition_units),
          c("Choose..." = "", labels)
        ),
        shiny::selectInput(
          session$ns("high"),
          paste("CSV label for", prior$conditions[2], prior$condition_units),
          c("Choose..." = "", labels)
        ),
        shiny::tags$p(sprintf(
          "Known measurement SDs: %s and %s %s. Review the prior if these assumptions are inappropriate.",
          prior$batch_sd[1],
          prior$batch_sd[2],
          prior$claim$units
        ))
      )
    })
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        record <- current()
        prior <- utils::tail(record$revisions, 1)[[1]]$candidate
        shiny::req(prior)
        check_text(input$low, "first condition label")
        check_text(input$high, "second condition label")
        evidence <- Filter(function(a) a$id %in% input$evidence, eligible())
        fit <- update_prior(
          prior,
          lapply(evidence, `[[`, "data"),
          stats::setNames(prior$conditions, c(input$low, input$high)),
          input$independent
        )
        proposed <- record_update(record, fit, input$reason)
        staged(list(
          fit = fit,
          record = proposed,
          base = object_id(record),
          config = config()
        ))
        status(
          "Update computed. Review its assumptions and model checks before retaining it."
        )
      })
    )
    shiny::observeEvent(
      input$retain,
      safely({
        guard()
        p <- staged()
        if (is.null(p)) {
          abort_suppose("Preview an update first.")
        }
        if (
          !identical(p$base, object_id(current())) ||
            !identical(p$config, config())
        ) {
          abort_suppose(
            "The record or inputs changed. Preview again before retaining.",
            "stale"
          )
        }
        current(p$record)
        staged(NULL)
        status("Update retained alongside its original prior and measurements.")
      })
    )
    output$status <- shiny::renderText(status())
    output$preview_card <- shiny::renderUI({
      p <- staged()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        update_diagnostics_ui(p$fit),
        shiny::plotOutput(session$ns("preview_plot"), height = "380px"),
        shiny::actionButton(session$ns("retain"), "Retain this update")
      )
    })
    output$preview_plot <- shiny::renderPlot(
      {
        shiny::req(staged())
        print(plot_update(staged()$fit))
      },
      alt = shiny::reactive(
        if (is.null(staged())) "" else update_summary_text(staged()$fit)
      )
    )
    output$retained <- shiny::renderUI({
      lapply(current()$updates, function(a) {
        key <- paste0("fit_", a$id)
        fit <- a$result
        output[[key]] <- shiny::renderPlot(
          {
            print(plot_update(fit))
          },
          alt = update_summary_text(fit)
        )
        output[[paste0(key, "_intervals")]] <- shiny::renderPlot(
          {
            print(plot_update(fit, "intervals"))
          },
          alt = update_summary_text(fit)
        )
        shiny::tags$details(
          shiny::tags$summary(paste("Update of revision", a$revision)),
          inquiry_field("Reason", a$reason),
          update_diagnostics_ui(fit),
          shiny::plotOutput(session$ns(key), height = "380px"),
          shiny::plotOutput(
            session$ns(paste0(key, "_intervals")),
            height = "280px"
          )
        )
      })
    })
    list(staged = staged, status = status)
  })
}
