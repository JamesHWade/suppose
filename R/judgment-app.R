#' Retain an additional expectation without fitting it
#'
#' Adds a record entry containing the current claim, candidate, predictions and
#' all earlier judgments from that entry. Earlier acceptance remains intact;
#' acceptance is not transferred to the new entry. Repeating the same sealed
#' judgment is an error. This operation does not refit the candidate.
#' @param x An elicitation record.
#' @param judgment A judgment created with [judgment()].
#' @param reason Why this expectation is being added.
#' @return An updated record.
#' @export
record_judgment <- function(x, judgment, reason) {
  validate_record(x)
  check_seal(judgment, "suppose_judgment")
  entry <- utils::tail(x$revisions, 1)[[1]]
  if (
    any(vapply(entry$judgments, function(j) j$id == judgment$id, logical(1)))
  ) {
    abort_suppose("This judgment is already retained.", "duplicate")
  }
  record_revision(
    x,
    entry$claim,
    entry$candidate,
    entry$prediction,
    reason = reason,
    judgments = c(entry$judgments, list(judgment))
  )
}

judgment_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    shiny::tags$summary("Record an expectation"),
    shiny::tags$p(
      "Retain a range, explicit quantiles, a comparison, or an expected shape. This records your answer without fitting it or changing the current model."
    ),
    shiny::selectInput(
      ns("kind"),
      "Answer type",
      c(
        "Plausible range" = "range",
        "Quantiles" = "quantile",
        "Comparison" = "comparison",
        "Qualitative shape" = "qualitative"
      ),
      selectize = FALSE
    ),
    shiny::selectInput(
      ns("quantity"),
      "What is uncertain?",
      c(
        "Population mean" = "mean",
        "Future batch" = "batch",
        "Individual specimen" = "specimen",
        "Difference" = "contrast",
        "Response shape" = "shape"
      ),
      selectize = FALSE
    ),
    shiny::numericInput(ns("condition"), "Condition", 0),
    shiny::textInput(ns("condition_units"), "Condition units"),
    shiny::textInput(
      ns("reference"),
      "Reference condition or other end of shape region (optional)"
    ),
    shiny::textInput(ns("units"), "Outcome units"),
    shiny::textAreaInput(ns("answer"), "Your original answer", width = "100%"),
    shiny::textInput(
      ns("values"),
      "Numerical values, comma separated (optional)"
    ),
    shiny::textInput(
      ns("probabilities"),
      "Cumulative probabilities for quantiles, comma separated"
    ),
    shiny::textAreaInput(
      ns("rationale"),
      "Reason or supporting information",
      width = "100%"
    ),
    shiny::textInput(ns("source"), "Source (optional)"),
    shiny::textAreaInput(
      ns("observed"),
      "Information already observed (one item per line; blank means unknown)",
      width = "100%"
    ),
    shiny::actionButton(ns("preview"), "Review this expectation"),
    shiny::uiOutput(ns("preview_card")),
    shiny::uiOutput(ns("status")),
    shiny::uiOutput(ns("retained"))
  )
}

judgment_details <- function(j, fitted = FALSE) {
  shiny::tags$div(
    shiny::tags$p(sprintf(
      "%s about %s at %s %s%s; outcome units: %s. Author: %s.",
      j$kind,
      j$quantity,
      j$condition,
      j$condition_units,
      if (is.null(j$reference_condition)) {
        ""
      } else {
        paste(
          "; reference / region endpoint",
          j$reference_condition,
          j$condition_units
        )
      },
      j$units,
      j$author
    )),
    shiny::tags$blockquote(j$answer),
    if (length(j$values)) {
      shiny::tags$p(paste("Values:", paste(j$values, collapse = ", ")))
    },
    if (length(j$probabilities)) {
      shiny::tags$p(paste(
        "Cumulative probabilities:",
        paste(j$probabilities, collapse = ", ")
      ))
    },
    inquiry_field("Rationale", j$rationale),
    inquiry_field("Source", j$source),
    inquiry_field("Already observed", j$observed),
    shiny::tags$p(
      if (fitted) {
        "Used to fit the current prior."
      } else {
        "Retained expectation; not used to fit the current model."
      }
    ),
    shiny::tags$ul(lapply(j$issues, shiny::tags$li))
  )
}

judgment_server <- function(id, current, guard, author = function() "You") {
  shiny::moduleServer(id, function(input, output, session) {
    preview <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(NULL)
    fields <- shiny::reactive(list(
      kind = input$kind,
      quantity = input$quantity,
      condition = input$condition,
      condition_units = input$condition_units,
      reference = input$reference,
      units = input$units,
      answer = input$answer,
      values = input$values,
      probabilities = input$probabilities,
      rationale = input$rationale,
      source = input$source,
      observed = input$observed,
      author = author()
    ))
    optional <- function(s) if (is.null(s) || !nzchar(trimws(s))) NULL else s
    numbers <- function(s) {
      if (is.null(optional(s))) {
        return(NULL)
      }
      x <- suppressWarnings(as.numeric(trimws(strsplit(s, ",", fixed = TRUE)[[
        1
      ]])))
      if (!length(x) || !all(is.finite(x))) {
        abort_suppose("Use finite numbers separated by commas.")
      }
      x
    }
    output$status <- shiny::renderUI(shiny::tags$p(role = "status", status()))
    shiny::observeEvent(input$preview, {
      preview(NULL)
      tryCatch(
        {
          guard()
          if (is.null(current())) {
            abort_suppose(
              "Retain an interpretation before recording an expectation."
            )
          }
          f <- fields()
          j <- judgment(
            f$condition,
            numbers(f$values),
            numbers(f$probabilities),
            kind = f$kind,
            quantity = f$quantity,
            units = f$units,
            author = f$author,
            answer = f$answer,
            rationale = optional(f$rationale),
            source = optional(f$source),
            observed = if (is.null(optional(f$observed))) {
              NULL
            } else {
              strsplit(f$observed, "\n", fixed = TRUE)[[1]]
            },
            condition_units = f$condition_units,
            reference_condition = numbers(f$reference)
          )
          preview(list(judgment = j, fields = f, basis = object_id(current())))
          status("Review the interpretation below before retaining it.")
        },
        error = function(e) status(conditionMessage(e))
      )
    })
    output$preview_card <- shiny::renderUI({
      p <- preview()
      if (is.null(p)) {
        return(NULL)
      }
      shiny::tagList(
        judgment_details(p$judgment),
        shiny::actionButton(session$ns("retain"), "Retain this expectation")
      )
    })
    shiny::observeEvent(input$retain, {
      tryCatch(
        {
          guard()
          p <- preview()
          if (is.null(p)) {
            abort_suppose("Review an expectation before retaining it.")
          }
          if (
            !identical(p$fields, fields()) ||
              !identical(p$basis, object_id(current()))
          ) {
            abort_suppose(
              "The form or record changed. Review the expectation again before retaining it.",
              "stale"
            )
          }
          current(record_judgment(
            current(),
            p$judgment,
            "Retain an additional expectation"
          ))
          preview(NULL)
          status(
            "Expectation retained. The model was not refitted; earlier reviews remain in history."
          )
        },
        error = function(e) status(conditionMessage(e))
      )
    })
    output$retained <- shiny::renderUI({
      x <- current()
      if (is.null(x)) {
        return(NULL)
      }
      e <- utils::tail(x$revisions, 1)[[1]]
      fitted <- vapply(e$candidate$judgments, function(j) j$id, character(1))
      shiny::tagList(lapply(e$judgments, function(j) {
        judgment_details(j, j$id %in% fitted)
      }))
    })
  })
}
