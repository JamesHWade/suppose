inquiry_review_labels <- function() {
  c(
    wording = "Belief or question",
    target = "What to observe or compare",
    scope = "Scope",
    horizon = "Time horizon",
    units = "Units, if relevant",
    expectations = "Your expectations (one complete statement per line)",
    assumptions = "Assumptions you adopt (one per line)",
    unresolved = "Open questions (one per line)"
  )
}

inquiry_correction_modal <- function(proposal) {
  labels <- inquiry_review_labels()
  shiny::modalDialog(
    title = "Correct the suggestion",
    shiny::tags$p(
      "Edit what the assistant proposed. Applying this correction creates a new, unaccepted revision and keeps the original suggestion in its history."
    ),
    if (!is.null(proposal$candidate)) {
      shiny::tags$p(
        "Changing the interpretation removes the proposed numerical model and its results from this new revision. Earlier revisions are preserved."
      )
    },
    lapply(names(labels), function(nm) {
      shiny::textAreaInput(
        paste0("correct_", nm),
        labels[[nm]],
        value = paste(proposal$claim[[nm]] %||% "", collapse = "\n"),
        width = "100%"
      )
    }),
    inquiry_field(
      "Assistant ideas to consider; not adopted",
      proposal$changes$ideas
    ),
    shiny::textInput(
      "correction_reason",
      "Why are you changing the suggestion?",
      "Correct the assistant's interpretation"
    ),
    footer = shiny::tagList(
      shiny::modalButton("Cancel"),
      shiny::actionButton(
        "apply_correction",
        "Apply corrected interpretation",
        class = "btn-primary"
      )
    ),
    size = "l",
    easyClose = FALSE
  )
}

inquiry_corrections <- function(values, proposed) {
  fields <- names(inquiry_review_labels())
  if (!is.list(values) || !identical(names(values), fields)) {
    abort_suppose(
      "The correction form is incomplete. Reopen the suggestion editor.",
      "review"
    )
  }
  for (nm in fields) {
    value <- values[[nm]]
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
      abort_suppose(
        "The correction form is incomplete. Reopen the suggestion editor.",
        "review"
      )
    }
    if (nm %in% c("expectations", "assumptions", "unresolved")) {
      value <- trimws(strsplit(value, "\n", fixed = TRUE)[[1]])
      value <- value[nzchar(value)]
      if (!length(value)) value <- NULL
    } else {
      value <- trimws(value)
      if (!nzchar(value)) value <- NULL
    }
    values[nm] <- list(value)
  }
  check_text(values$wording, "wording")
  values[
    !vapply(
      fields,
      function(nm) {
        identical(values[[nm]], proposed[[nm]]) ||
          (length(values[[nm]]) == 0L && length(proposed[[nm]]) == 0L)
      },
      logical(1)
    )
  ]
}

inquiry_source_details <- function(proposal) {
  sources <- proposal$changes$statement_sources
  if (!length(sources)) {
    return(NULL)
  }
  shiny::tags$details(
    shiny::tags$summary("Source context for expectations and assumptions"),
    shiny::tags$p(
      class = "hint",
      "The wording was quoted from your messages. Check whether it expresses an expectation or assumption you actually hold; quotation alone does not establish that."
    ),
    lapply(sources, function(source) {
      shiny::tags$div(
        inquiry_field(
          if (source$field == "expectations") "Expectation" else "Assumption",
          source$statement
        ),
        inquiry_field("Full source message", source$source_message)
      )
    })
  )
}
