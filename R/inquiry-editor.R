# The record editor in the drawer: the retained interpretation and its model,
# the pending suggestion, manual edits, review and acceptance, and revision
# history. `decline` marks a request's decision cards declined.
inquiry_editor_server <- function(
  input,
  output,
  session,
  state,
  assistant,
  busy,
  safely,
  decline
) {
  current <- state$current
  proposal <- state$proposal
  editing_proposal <- state$editing_proposal
  status <- state$status
  transcript <- state$transcript
  latest <- state$latest
  visible <- state$visible
  sync_editor <- function() {
    e <- shiny::isolate(latest())
    for (nm in c(
      "wording",
      "target",
      "scope",
      "expectations",
      "assumptions",
      "unresolved"
    )) {
      shiny::updateTextAreaInput(
        session,
        nm,
        value = paste(e$claim[[nm]] %||% "", collapse = "\n")
      )
    }
    shiny::updateTextInput(session, "horizon", value = e$claim$horizon %||% "")
    shiny::updateTextInput(session, "units", value = e$claim$units %||% "")
    shiny::updateTextInput(session, "author", value = e$claim$author %||% "You")
    shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
  }
  shiny::observeEvent(
    current(),
    {
      sync_editor()
    },
    ignoreNULL = FALSE
  )
  output$record_card <- shiny::renderUI({
    e <- visible()
    if (is.null(e)) {
      return(shiny::tags$p(
        class = "hint",
        "Your question, expectations, assumptions and open questions will take shape here. Start the conversation or write an interpretation in the editor."
      ))
    }
    shiny::tagList(
      shiny::tags$h2("Retained interpretation"),
      inquiry_fields(e$claim),
      if (!identical(e$claim$wording, e$claim$original_wording)) {
        shiny::tags$details(
          shiny::tags$summary("Your original words"),
          shiny::tags$p(e$claim$original_wording)
        )
      }
    )
  })
  output$model_card <- shiny::renderUI({
    if (is.null(visible())) {
      return(NULL)
    }
    if (is.null(visible()$candidate)) {
      return(NULL)
    }
    shiny::tags$details(
      open = TRUE,
      shiny::tags$summary("Optional model and its consequences"),
      inquiry_prediction(visible(), "record_prior_plot")
    )
  })
  bind_inquiry_prior(
    output,
    "record_prior_plot",
    shiny::reactive(inquiry_prior_visual(visible()))
  )
  bind_inquiry_prior(
    output,
    "proposal_prior_plot",
    shiny::reactive(inquiry_prior_visual(proposal()))
  )
  output$proposal_card <- shiny::renderUI({
    p <- proposal()
    if (is.null(p)) {
      return(NULL)
    }
    shiny::tags$div(
      class = "proposal",
      shiny::tags$h2("Proposed interpretation"),
      inquiry_field("Current wording", latest()$claim$wording),
      inquiry_change_summary(latest()$claim, p$claim),
      inquiry_fields(p$claim),
      inquiry_source_details(p),
      inquiry_field(
        "Assistant ideas to consider; not adopted",
        p$changes$ideas
      ),
      inquiry_prediction(p, "proposal_prior_plot"),
      inquiry_field("Why this change", p$reason),
      shiny::tags$details(
        shiny::tags$summary("Source words"),
        shiny::tags$p(paste(
          unique(vapply(p$changes$sources, `[[`, character(1), "quote")),
          collapse = "\n\n"
        ))
      ),
      shiny::actionButton(
        "apply",
        "Apply interpretation",
        class = "btn-primary"
      ),
      shiny::actionButton("decline", "Decline"),
      shiny::actionButton("edit_proposal", "Correct suggestion"),
      shiny::tags$hr()
    )
  })
  change_proposal <- function(action, request_id = NULL) {
    busy()
    p <- proposal()
    if (is.null(p)) {
      abort_suppose("There is no completed suggestion to review.", "proposal")
    }
    if (!is.null(request_id) && !identical(p$context$request_id, request_id)) {
      abort_suppose("The suggestion changed. Review the latest draft.", "stale")
    }
    if (action != "decline" && !editor_matches_record()) {
      abort_suppose(
        "Retain your editor changes before applying or correcting a suggestion.",
        "stale"
      )
    }
    if (action == "apply") {
      current(apply_assistant_proposal(
        current(),
        p,
        input$author %||% latest()$claim$author
      ))
      assistant$clear_proposal()
      status(
        "Interpretation applied as a new revision. Review its meaning before accepting it."
      )
    } else if (action == "decline") {
      decline(p$context$request_id)
      assistant$clear_proposal()
      status("Suggestion declined. The retained interpretation is unchanged.")
    } else if (action == "edit") {
      editing_proposal(p)
      shiny::showModal(inquiry_correction_modal(p))
    }
  }
  shiny::observeEvent(input$apply, safely(change_proposal("apply")))
  shiny::observeEvent(input$decline, safely(change_proposal("decline")))
  shiny::observeEvent(input$edit_proposal, safely(change_proposal("edit")))
  shiny::observeEvent(
    input$apply_correction,
    safely({
      busy()
      p <- editing_proposal()
      if (is.null(p) || !identical(p$id, proposal()$id)) {
        abort_suppose(
          "The suggestion changed. Close this editor and review the latest suggestion.",
          "stale"
        )
      }
      if (!editor_matches_record()) {
        abort_suppose(
          "The manual editor changed. Retain those changes before applying a corrected suggestion.",
          "stale"
        )
      }
      values <- lapply(names(inquiry_review_labels()), function(nm) {
        input[[paste0("correct_", nm)]]
      })
      names(values) <- names(inquiry_review_labels())
      corrections <- inquiry_corrections(values, p$claim)
      current(apply_assistant_proposal(
        current(),
        p,
        input$author %||% latest()$claim$author,
        corrections = corrections,
        reason = input$correction_reason
      ))
      assistant$clear_proposal()
      editing_proposal(NULL)
      shiny::removeModal()
      status(
        "Corrected interpretation applied. Review it before accepting; the original suggestion is retained in history."
      )
    })
  )
  blank <- function(x) if (is.null(x) || !nzchar(trimws(x))) NULL else trimws(x)
  lines <- function(x) {
    if (is.null(blank(x))) {
      NULL
    } else {
      trimws(strsplit(x, "\n", fixed = TRUE)[[1]])[nzchar(trimws(strsplit(
        x,
        "\n",
        fixed = TRUE
      )[[1]]))]
    }
  }
  editor_matches_record <- function() {
    c <- latest()$claim
    if (is.null(c)) {
      return(FALSE)
    }
    all(vapply(
      c(
        "wording",
        "target",
        "scope",
        "horizon",
        "units",
        "expectations",
        "assumptions",
        "unresolved"
      ),
      function(nm) {
        identical(
          blank(input[[nm]]),
          blank(paste(c[[nm]] %||% "", collapse = "\n"))
        )
      },
      logical(1)
    ))
  }
  shiny::observeEvent(
    input$retain,
    safely({
      busy()
      fields <- list(
        wording = input$wording,
        target = blank(input$target),
        scope = blank(input$scope),
        horizon = blank(input$horizon),
        units = blank(input$units),
        threshold = NULL,
        expectations = lines(input$expectations),
        assumptions = lines(input$assumptions),
        unresolved = lines(input$unresolved)
      )
      if (is.null(current())) {
        current(elicitation_record(
          do.call(claim, c(fields, list(author = input$author))),
          "My inquiry"
        ))
      } else {
        c <- do.call(
          revise_claim,
          c(
            list(
              latest()$claim,
              author = input$author,
              reason = input$edit_reason
            ),
            fields
          )
        )
        current(record_revision(
          current(),
          c,
          reason = input$edit_reason,
          assistance = latest()$assistance
        ))
      }
      assistant$clear_proposal()
      status(
        "Interpretation retained. Earlier versions and their numerical results remain in history."
      )
    })
  )
  output$review_controls <- shiny::renderUI({
    e <- latest()
    if (is.null(e)) {
      return(NULL)
    }
    if (!is.null(proposal())) {
      return(shiny::tags$p(
        class = "hint",
        "Apply, correct, or decline the pending suggestion before accepting the retained interpretation."
      ))
    }
    if (!is.null(e$acceptance)) {
      return(shiny::tags$p(
        class = "hint",
        if (identical(e$acceptance$kind, "interpretation")) {
          "The latest interpretation has been reviewed. This is agreement about meaning, not a finding that it is true."
        } else {
          "The latest numerical candidate has been reviewed and accepted."
        }
      ))
    }
    shiny::tags$details(
      shiny::tags$summary("Review and accept"),
      shiny::textAreaInput(
        "review_reason",
        "Why does this express your meaning?",
        width = "100%"
      ),
      shiny::textAreaInput(
        "challenge",
        "What could change your mind?",
        width = "100%"
      ),
      shiny::checkboxInput(
        "reviewed",
        "I reviewed the retained interpretation and any model consequences"
      ),
      shiny::actionButton(
        "accept",
        if (is.null(e$candidate)) {
          "Accept this interpretation"
        } else {
          "Accept this numerical candidate"
        }
      )
    )
  })
  shiny::observeEvent(
    input$accept,
    safely({
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply, correct, or decline the pending suggestion before accepting the retained interpretation.",
          "review"
        )
      }
      if (!editor_matches_record()) {
        abort_suppose(
          "Retain your editor changes before reviewing this interpretation.",
          "stale"
        )
      }
      if (!isTRUE(input$reviewed)) {
        abort_suppose(
          "Confirm that you reviewed the retained interpretation.",
          "review"
        )
      }
      if (
        !identical(visible()$claim$id, latest()$claim$id) ||
          !identical(visible()$prediction$id, latest()$prediction$id)
      ) {
        abort_suppose(
          "Select the latest revision before accepting it.",
          "stale"
        )
      }
      fn <- if (is.null(latest()$candidate)) {
        accept_interpretation
      } else {
        accept_revision
      }
      current(fn(current(), input$author, input$review_reason, input$challenge))
      status(
        "Review recorded. Save the conversation and record to reopen them later."
      )
    })
  )
  output$revision_picker <- shiny::renderUI({
    if (is.null(current())) {
      return(NULL)
    }
    n <- length(current()$revisions)
    shiny::selectInput(
      "revision",
      "Inspect a retained revision",
      stats::setNames(seq_len(n), paste("Revision", seq_len(n))),
      selected = n
    )
  })
  output$review_details <- shiny::renderUI({
    e <- visible()
    if (is.null(e)) {
      return(NULL)
    }
    a <- e$acceptance
    shiny::tagList(
      if (is.null(a)) {
        shiny::tags$p("This revision is not accepted.")
      } else {
        shiny::tagList(
          inquiry_field("Reviewed by", a$author),
          inquiry_field("Review rationale", a$reason),
          inquiry_field("What could challenge it", a$challenge)
        )
      },
      if (!is.null(e$assistance)) {
        shiny::tagList(
          inquiry_field(
            "Assistant contribution",
            paste(
              e$assistance$proposal$context$model,
              "- applied by",
              e$assistance$applied_by
            )
          ),
          inquiry_field("Reviewer correction", e$assistance$correction_reason),
          shiny::tags$details(
            shiny::tags$summary("Original assistant suggestion"),
            inquiry_fields(e$assistance$proposal$claim),
            inquiry_source_details(e$assistance$proposal),
            inquiry_field(
              "Assistant ideas; not adopted by applying the suggestion",
              e$assistance$proposal$changes$ideas
            )
          )
        )
      }
    )
  })
  output$transcript <- shiny::renderText(paste(
    vapply(
      transcript(),
      function(m) paste(m$role, m$text, sep = ": "),
      character(1)
    ),
    collapse = "\n\n"
  ))
  list(change_proposal = change_proposal)
}
