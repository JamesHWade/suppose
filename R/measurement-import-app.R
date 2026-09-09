measurement_import_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    id = ns("panel"),
    shiny::tags$summary("Import a table"),
    shiny::tags$p(
      "Paste a table in chat and ask to import it, or paste/upload CSV here. Review one mapping to attach outcomes and numeric predictors together."
    ),
    shiny::uiOutput(ns("draft_notice")),
    shiny::tags$details(
      shiny::tags$summary("Table and column mapping"),
      shiny::fileInput(ns("csv_file"), "Table CSV", accept = ".csv"),
      shiny::textAreaInput(ns("csv_text"), "CSV table", rows = 7),
      shiny::textInput(
        ns("id_column"),
        "Measurement ID column",
        "observation_id"
      ),
      shiny::textInput(ns("outcome_column"), "Outcome column", "outcome"),
      shiny::textInput(
        ns("predictor_columns"),
        "Predictor columns (comma separated)"
      ),
      shiny::textInput(ns("predictor_units"), "Predictor units (same order)"),
      shiny::textInput(ns("condition_column"), "Condition column (optional)"),
      shiny::textInput(ns("batch_column"), "Batch column (optional)"),
      shiny::textInput(ns("specimen_column"), "Specimen column (optional)"),
      shiny::textInput(ns("observed_at_column"), "Timestamp column (optional)"),
      shiny::textInput(
        ns("observed_at"),
        "Common UTC timestamp or unknown",
        "unknown"
      ),
      shiny::tags$p(
        "Blank batch/specimen mappings remain unknown. Importing does not establish independence."
      )
    ),
    shiny::textInput(ns("source"), "Table source"),
    shiny::textInput(ns("protocol"), "Table measurement protocol"),
    shiny::textInput(ns("author"), "Table provenance declared by", "You"),
    shiny::textInput(ns("units"), "Table outcome units"),
    shiny::textInput(ns("collection_note"), "Collection details"),
    shiny::selectInput(
      ns("role"),
      "Use this table for",
      c(
        "Exploration" = "exploration",
        "Model update" = "update",
        "Assessment" = "assessment"
      )
    ),
    shiny::selectInput(
      ns("exposure"),
      "Previous exposure to these outcomes",
      c(
        "Unknown" = "unknown",
        "Unseen" = "unseen",
        "Already explored" = "explored",
        "Used in the prior" = "prior"
      )
    ),
    shiny::actionButton(ns("preview"), "Preview table import"),
    shiny::div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput(ns("status"))
    ),
    shiny::uiOutput(ns("preview_card"))
  )
}

measurement_import_server <- function(
  id,
  current,
  guard,
  draft = function() NULL,
  retained = function() NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    staged <- shiny::reactiveVal(NULL)
    source <- shiny::reactiveVal(NULL)
    incoming <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(
      "Chat can prepare this import from a pasted table."
    )
    safely <- function(code) {
      tryCatch(force(code), error = function(e) {
        status(cli::ansi_strip(conditionMessage(e)))
      })
    }
    words <- function(text) {
      out <- trimws(strsplit(text %||% "", "[,\n]")[[1]])
      out[nzchar(out)]
    }
    values <- shiny::reactive({
      v <- measurement_form_defaults(current())
      for (name in names(v)) {
        value <- input[[name]]
        if (!is.null(value)) v[[name]] <- value
      }
      v$predictor_columns <- words(input$predictor_columns)
      v$predictor_units <- words(input$predictor_units)
      v
    })
    form_state <- function() {
      list(values = values(), version = object_id(values()))
    }
    preview <- function(v, original = source()) {
      guard()
      if (is.null(current())) {
        abort_suppose("Start an inquiry before importing a table.")
      }
      result <- measurement_form_preview(current(), v, original)
      staged(list(
        result = result,
        values = v,
        base_id = proposal_basis_id(current())
      ))
      status(
        "Review the mapped measurements and provenance, then attach the table explicitly."
      )
    }
    restore <- function(d, force = FALSE) {
      safely({
        check_seal(d, "suppose_form_draft")
        if (
          !identical(d$form, "import") ||
            !identical(d$base_id, proposal_basis_id(current()))
        ) {
          abort_suppose(
            "The record changed. Ask chat to prepare this table again.",
            "stale"
          )
        }
        if (
          !force &&
            !is.null(d$form_base_id) &&
            !identical(d$form_base_id, form_state()$version)
        ) {
          incoming(d)
          status(
            "Your table inputs changed while chat was working. Review the draft before replacing them."
          )
          return(invisible(NULL))
        }
        for (name in names(d$values)) {
          value <- d$values[[name]]
          if (name %in% c("predictor_columns", "predictor_units")) {
            value <- paste(value, collapse = ", ")
          }
          if (name == "csv_text") {
            shiny::updateTextAreaInput(session, name, value = value)
          } else if (name %in% c("role", "exposure")) {
            shiny::updateSelectInput(session, name, selected = value)
          } else {
            shiny::updateTextInput(session, name, value = value)
          }
        }
        source(d)
        incoming(NULL)
        preview(d$values, d)
      })
    }
    shiny::observeEvent(
      current()$revisions[[1]]$claim$id,
      {
        staged(NULL)
        source(NULL)
        incoming(NULL)
      },
      ignoreNULL = FALSE
    )
    shiny::observeEvent(draft(), restore(draft()), ignoreNULL = TRUE)
    shiny::observeEvent(input$use_draft, restore(incoming(), force = TRUE))
    shiny::observeEvent(
      input$csv_file,
      safely({
        guard()
        if (file.info(input$csv_file$datapath)$size > 500000L) {
          abort_suppose("Use a CSV file of at most 500 KB.")
        }
        text <- paste(
          readLines(input$csv_file$datapath, warn = FALSE),
          collapse = "\n"
        )
        measurement_table(text)
        shiny::updateTextAreaInput(session, "csv_text", value = text)
        staged(NULL)
        status(
          "Table loaded. Review the column mapping and provenance, then preview."
        )
      })
    )
    shiny::observeEvent(input$preview, safely(preview(values())))
    shiny::observeEvent(
      input$attach,
      safely({
        guard()
        p <- staged()
        if (is.null(p)) {
          abort_suppose("Preview this table before attaching it.")
        }
        if (
          !identical(p$base_id, proposal_basis_id(current())) ||
            !identical(object_id(p$values), object_id(values()))
        ) {
          staged(NULL)
          abort_suppose(
            "The table, mapping or record changed. Preview again before attaching.",
            "stale"
          )
        }
        # Rebuild against the live record so concurrent saved R analyses survive.
        current(measurement_form_preview(current(), values(), source())$record)
        staged(NULL)
        source(NULL)
        retained()
        status(
          "Table attached: outcomes and linked predictors are retained together. Ask chat to prepare the regression priors."
        )
      })
    )
    output$status <- shiny::renderText(status())
    output$draft_notice <- shiny::renderUI({
      if (!is.null(incoming())) {
        shiny::actionButton(session$ns("use_draft"), "Use chat import draft")
      }
    })
    output$preview_card <- shiny::renderUI({
      p <- staged()
      if (is.null(p)) {
        return(NULL)
      }
      v <- p$values
      shiny::tagList(
        shiny::tags$h3("Review table import"),
        inquiry_field(
          "Outcome mapping",
          paste(v$outcome_column, "in", v$units)
        ),
        inquiry_field(
          "Measurement identity",
          paste(
            "ID:",
            v$id_column,
            "Batch:",
            if (nzchar(v$batch_column)) v$batch_column else "unknown",
            "Specimen:",
            if (nzchar(v$specimen_column)) v$specimen_column else "unknown"
          )
        ),
        inquiry_field("Collection", v$collection_note),
        inquiry_field(
          "Predictor mapping",
          paste(v$predictor_columns, v$predictor_units, collapse = "; ")
        ),
        observations_summary(p$result$data),
        if (!is.null(p$result$predictors)) {
          shiny::tags$div(
            style = "overflow-x:auto;",
            shiny::tags$table(
              class = "table table-sm",
              shiny::tags$caption("First 20 linked predictor rows"),
              shiny::tags$thead(shiny::tags$tr(lapply(
                c("observation_id", v$predictor_columns),
                shiny::tags$th
              ))),
              shiny::tags$tbody(lapply(
                utils::head(p$result$predictors$rows, 20),
                function(row) {
                  shiny::tags$tr(lapply(row, shiny::tags$td))
                }
              ))
            )
          )
        },
        shiny::tags$p(
          "Review all mappings and provenance. This attaches evidence; it does not fit a model or establish independence."
        ),
        shiny::actionButton(
          session$ns("attach"),
          "Attach reviewed table",
          class = "btn-primary"
        )
      )
    })
    list(
      staged = staged,
      status = status,
      restore = function(d) restore(d, force = TRUE),
      form_state = form_state,
      values = values
    )
  })
}
