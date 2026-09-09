#' Relate an independently worded claim to a retained model
#'
#' A reference records a person's explanation of a model's implications for a
#' claim. It does not assert that the model was fitted to that claim, accept a
#' formalization, or establish evidence. Multiple claims can reference the same
#' model and each claim can reference several models. Claims need no model.
#' @param x An elicitation record containing the referenced candidate prior.
#' @param claim A sealed claim, including a claim from a different lineage.
#' @param model_id Identifier of a candidate prior retained in this record.
#' @param author Person recording the relationship.
#' @param reason Explanation of the relationship, scope and limitations.
#' @return An updated record containing an explicit, attributed reference.
#' @export
record_model_reference <- function(x, claim, model_id, author, reason) {
  validate_record(x)
  check_seal(claim, "suppose_claim")
  for (arg in c("model_id", "author", "reason")) {
    check_text(get(arg), arg)
  }
  entry <- seal(
    list(
      claim = claim,
      model_id = model_id,
      author = author,
      reason = reason,
      created_at = now_utc()
    ),
    "suppose_model_reference"
  )
  if (
    any(vapply(
      x$model_references,
      function(r) {
        identical(r$claim$id, claim$id) && identical(r$model_id, model_id)
      },
      logical(1)
    ))
  ) {
    abort_suppose("This claim already references this model.", "duplicate")
  }
  x$model_references <- c(x$model_references, list(entry))
  x$schema_version <- max(x$schema_version, 12L)
  validate_record(x)
  x
}

validate_model_references <- function(x) {
  refs <- x$model_references
  if (is.null(refs)) {
    return(invisible(x))
  }
  if (x$schema_version < 12L || !is.list(refs)) {
    abort_suppose("Invalid model references.", "record")
  }
  models <- vapply(
    x$revisions,
    function(e) e$candidate$id %||% "",
    character(1)
  )
  pairs <- character()
  for (r in refs) {
    check_seal(r, "suppose_model_reference")
    check_seal(r$claim, "suppose_claim")
    for (arg in c("model_id", "author", "reason")) {
      check_text(r[[arg]], arg)
    }
    if (!r$model_id %in% models) {
      abort_suppose(
        "The referenced model is not retained in this record.",
        "reference"
      )
    }
    pairs <- c(pairs, paste(r$claim$id, r$model_id))
  }
  if (anyDuplicated(pairs)) {
    abort_suppose("Duplicate claim-to-model references.", "duplicate")
  }
  invisible(x)
}

model_reference_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    shiny::tags$summary("Relate a claim to a retained prior"),
    shiny::tags$p(
      "A model can have implications for several claims. A reference records that relationship; it does not refit or accept the model."
    ),
    shiny::selectInput(
      ns("model"),
      "Retained prior",
      character(),
      selectize = FALSE
    ),
    shiny::selectInput(
      ns("claim"),
      "Claim to relate",
      character(),
      selectize = FALSE
    ),
    shiny::textAreaInput(
      ns("wording"),
      "Wording for a separate claim (when selected)",
      width = "100%"
    ),
    shiny::textAreaInput(
      ns("reason"),
      "How does this model bear on the claim? Include scope and limitations.",
      width = "100%"
    ),
    shiny::actionButton(ns("retain"), "Retain this relationship"),
    shiny::uiOutput(ns("status")),
    shiny::uiOutput(ns("retained"))
  )
}

model_reference_server <- function(
  id,
  current,
  guard,
  author = function() "You"
) {
  shiny::moduleServer(id, function(input, output, session) {
    status <- shiny::reactiveVal(NULL)
    last_submission <- shiny::reactiveVal(NULL)
    claims <- shiny::reactive({
      x <- current()
      out <- c(
        lapply(x$revisions, function(e) e$claim),
        lapply(x$model_references, function(r) r$claim)
      )
      out[!duplicated(vapply(out, function(c) c$id, character(1)))]
    })
    shiny::observe({
      x <- current()
      entries <- Filter(function(e) !is.null(e$candidate), x$revisions)
      models <- vapply(entries, function(e) e$candidate$id, character(1))
      models <- models[!duplicated(models)]
      shiny::updateSelectInput(
        session,
        "model",
        choices = stats::setNames(
          models,
          vapply(
            models,
            function(m) paste("Prior", substr(m, 1, 12)),
            character(1)
          )
        ),
        selected = shiny::isolate(input$model)
      )
      cs <- claims()
      ids <- vapply(cs, function(c) c$id, character(1))
      labels <- vapply(
        cs,
        function(c) paste(substr(c$wording, 1, 65), substr(c$id, 1, 8)),
        character(1)
      )
      shiny::updateSelectInput(
        session,
        "claim",
        choices = c(stats::setNames(ids, labels), "A separate claim" = "new"),
        selected = shiny::isolate(input$claim)
      )
    })
    shiny::observeEvent(input$retain, {
      tryCatch(
        {
          guard()
          submitted <- list(
            input$model,
            input$claim,
            input$wording,
            input$reason,
            author()
          )
          if (identical(submitted, last_submission())) {
            abort_suppose(
              "This relationship was just retained. Change the claim, model or reason before submitting again.",
              "duplicate"
            )
          }
          if (identical(input$claim, "new")) {
            c <- claim(input$wording, author())
          } else {
            cs <- claims()
            found <- Filter(function(c) identical(c$id, input$claim), cs)
            if (length(found) != 1L) {
              abort_suppose(
                "Choose a retained claim or write a separate claim."
              )
            }
            c <- found[[1]]
          }
          current(record_model_reference(
            current(),
            c,
            input$model,
            author(),
            input$reason
          ))
          last_submission(submitted)
          status(
            "Relationship retained. Fitting and acceptance records are unchanged."
          )
        },
        error = function(e) status(conditionMessage(e))
      )
    })
    output$status <- shiny::renderUI(shiny::tags$p(role = "status", status()))
    output$retained <- shiny::renderUI(lapply(
      current()$model_references,
      function(r) {
        shiny::tags$div(
          shiny::tags$blockquote(r$claim$wording),
          shiny::tags$p(paste(
            "Prior",
            substr(r$model_id, 1, 12),
            "\u2014 recorded by",
            r$author
          )),
          shiny::tags$p(r$reason)
        )
      }
    ))
  })
}
