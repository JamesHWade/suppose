observations_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Measured observations"),
    shiny::tags$p(
      "Retain measurements with their source and intended use. Importing does not fit a model or test the belief."
    ),
    shiny::uiOutput(ns("retained")),
    shiny::tags$p(
      "CSV columns: observation_id, condition, outcome, batch, specimen, observed_at. Leave missing outcomes blank; use UTC times such as 2026-09-08T12:00:00Z or unknown if not documented."
    ),
    shiny::fileInput(ns("csv"), "Measurements CSV", accept = ".csv"),
    shiny::textInput(ns("source"), "Stable source identifier"),
    shiny::textInput(ns("protocol"), "Measurement protocol"),
    shiny::textInput(ns("author"), "Person declaring provenance"),
    shiny::textInput(ns("units"), "Outcome units in CSV"),
    shiny::selectInput(
      ns("role"),
      "Intended use",
      c(
        "Exploration" = "exploration",
        "Model update" = "update",
        "Assessment" = "assessment"
      )
    ),
    shiny::selectInput(
      ns("exposure"),
      "Exposure when forming this claim",
      c(
        "Unknown" = "unknown",
        "Not previously examined" = "unseen",
        "Already explored" = "explored",
        "Already incorporated into the prior" = "prior"
      )
    ),
    shiny::tags$p(
      "A declaration of unseen outcomes does not establish an independent or prospective test."
    ),
    shiny::tags$details(
      shiny::tags$summary("Convert outcome units"),
      shiny::textInput(
        ns("target_units"),
        "Converted units (blank keeps original units)"
      ),
      shiny::numericInput(ns("scale"), "Multiply outcome by", 1),
      shiny::numericInput(ns("offset"), "Then add", 0)
    ),
    shiny::textInput(ns("reason"), "Why attach these measurements?"),
    shiny::actionButton(ns("preview"), "Preview import"),
    shiny::div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    ),
    shiny::uiOutput(ns("preview_card"))
  )
}

observations_summary <- function(d) {
  shiny::tagList(
    inquiry_field("Source", d$source),
    inquiry_field("Protocol", d$protocol),
    inquiry_field("Declared by", d$author),
    inquiry_field("Use and exposure", paste(d$role, d$exposure, sep = "; ")),
    shiny::tags$p(sprintf(
      "%d rows; %d missing outcomes; %d rows with repeated measurement fields (retained).",
      length(d$rows),
      length(d$missing_ids),
      length(d$repeated_ids)
    )),
    shiny::tags$p(sprintf(
      "Conversion: outcome \u00d7 %s + %s, from %s to %s.",
      d$conversion$scale,
      d$conversion$offset,
      d$units,
      d$target_units
    )),
    shiny::tags$div(
      style = "overflow-x:auto;",
      shiny::tags$table(
        class = "table table-sm",
        shiny::tags$caption(
          "First 20 measurements; all rows are retained in the saved record."
        ),
        shiny::tags$thead(shiny::tags$tr(lapply(
          c("ID", "Condition", "Original", "Converted", "Time"),
          function(label) shiny::tags$th(scope = "col", label)
        ))),
        shiny::tags$tbody(lapply(utils::head(d$rows, 20), function(row) {
          shiny::tags$tr(lapply(
            list(
              row$observation_id,
              row$condition,
              row$outcome %||% "Missing",
              row$converted %||% "Missing",
              row$observed_at
            ),
            shiny::tags$td
          ))
        }))
      )
    )
  )
}

observations_server <- function(id, current, guard) {
  shiny::moduleServer(id, function(input, output, session) {
    staged <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal("Preview the import before attaching it.")
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    config <- shiny::reactive(list(
      input$csv,
      input$source,
      input$protocol,
      input$author,
      input$units,
      input$role,
      input$exposure,
      input$target_units,
      input$scale,
      input$offset,
      input$reason
    ))
    shiny::observeEvent(
      input$preview,
      safely({
        guard()
        if (is.null(current())) {
          abort_suppose(
            "Retain an interpretation before attaching measurements."
          )
        }
        if (is.null(input$csv)) {
          abort_suppose("Choose a measurements CSV before previewing.")
        }
        target <- if (nzchar(trimws(input$target_units))) {
          input$target_units
        } else {
          input$units
        }
        d <- import_observations(
          input$csv$datapath,
          input$source,
          input$protocol,
          input$author,
          input$units,
          input$role,
          input$exposure,
          target,
          input$scale,
          input$offset
        )
        proposed <- record_observations(current(), d, input$reason)
        staged(list(
          data = d,
          record = proposed,
          base = object_id(current()),
          config = config()
        ))
        status(
          "Review the measurements and provenance, then attach explicitly."
        )
      })
    )
    shiny::observeEvent(
      input$attach,
      safely({
        guard()
        preview <- staged()
        if (is.null(preview)) {
          abort_suppose("Preview an import first.")
        }
        if (
          !identical(preview$config, config()) ||
            !identical(preview$base, object_id(current()))
        ) {
          staged(NULL)
          abort_suppose(
            "The inputs or claim changed. Preview the import again before attaching.",
            "stale"
          )
        }
        current(preview$record)
        staged(NULL)
        status(
          "Measurements attached to the record. You can download a portable copy."
        )
      })
    )
    output$status <- shiny::renderText(status())
    output$preview_card <- shiny::renderUI({
      p <- staged()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        shiny::tags$h3("Import preview"),
        observations_summary(p$data),
        shiny::actionButton(session$ns("attach"), "Attach these measurements")
      )
    })
    output$retained <- shiny::renderUI({
      lapply(current()$observations, function(a) {
        shiny::tags$details(
          shiny::tags$summary(sprintf(
            "Revision %s: %s",
            a$revision,
            a$data$source
          )),
          inquiry_field("Reason", a$reason),
          observations_summary(a$data)
        )
      })
    })
    list(staged = staged, status = status)
  })
}
