inquiry_suggestion_prompt <- function() {
  paste(
    "For most substantive replies, end with two or three useful, distinct next-step suggestions.",
    "Use shinychat's native suggestion cards: a Markdown list whose items each contain",
    "one <span class=\"suggestion submit\" title=\"Short action label\">First-person prompt to send</span>.",
    "Put explanations in preceding prose. Start a separate suggestions-only list; never mix ordinary list items with suggestions.",
    "Write the prompts yourself for this particular conversation. Clicking a submit suggestion sends that exact prompt.",
    "Never auto-submit placeholders such as LOW or HIGH. If a template needs the user to enter numbers or facts, use class=\"suggestion\" without submit so it only fills the composer for editing; label it as a template.",
    "Offer requests to explore, explain, compare or draft, not invented user facts, measurements,",
    "commitments, consent or conclusions. Never suggest an answer to your own factual question as if",
    "the user had supplied it. A card must not accept a record, enable tools or imply a decision was made.",
    "Do not suggest 'I attached the table' or 'I accepted the model'. Suggest 'Prepare the regression after checking the attached data' instead; the actual record determines what has happened.",
    "Keep titles short and prompts to one sentence. Use plain text inside the span and escape HTML",
    "special characters. Omit suggestions for brief acknowledgments, closure, or when they add no value.",
    "When presenting a small set of possible next actions or discussion directions, use these cards",
    "instead of asking the user to type a choice number. Explain meaningful tradeoffs before the cards.",
    "Actual interpretation decisions use the app's inline review card after the response completes.",
    "Do not write HTML buttons, Shiny input IDs, scripts, or pretend that prose performs an app action."
  )
}

inquiry_card_state <- function(card, proposal, record) {
  revisions <- record$revisions %||% list()
  applied <- which(vapply(
    revisions,
    function(revision) {
      identical(
        revision$assistance$proposal$context$request_id,
        card$request_id
      )
    },
    logical(1)
  ))
  if (length(applied)) {
    return(paste("Applied as revision", utils::tail(applied, 1)))
  }
  if (identical(card$outcome, "declined")) {
    return("Declined")
  }
  if (
    !is.null(proposal) &&
      identical(proposal$context$request_id, card$request_id) &&
      identical(proposal$base_id, object_id(record))
  ) {
    return("ready")
  }
  "This draft is no longer awaiting a decision."
}

# What one card shows. Only the ready, newest draft of a request carries the
# proposal, so other cards don't change when the suggestion does.
inquiry_card_view <- function(key, entries, proposal, record, running) {
  entry <- entries[[key]]
  if (is.null(entry)) {
    return(NULL)
  }
  state <- inquiry_card_state(entry, proposal, record)
  same_request <- Filter(
    function(x) identical(x$request_id, entry$request_id),
    entries
  )
  newest <- identical(utils::tail(names(same_request), 1), key)
  ready <- identical(state, "ready") && !running && newest
  list(
    wording = if (ready) proposal$claim$wording else entry$wording,
    visual = !is.null(entry$visual),
    proposal = if (ready) proposal,
    note = if (ready) {
      NULL
    } else if (running) {
      "Available after the response finishes."
    } else if (!newest) {
      "Updated by a later draft in this response."
    } else {
      state
    }
  )
}

inquiry_card_ui <- function(key, view) {
  if (is.null(view)) {
    return(NULL)
  }
  p <- view$proposal
  shiny::tags$section(
    class = "inquiry-chat-decision",
    `aria-label` = "Interpretation decision",
    shiny::tags$p(class = "hint", "Proposed interpretation"),
    shiny::tags$p(view$wording),
    if (view$visual) {
      shiny::tagList(
        inquiry_prior_output(paste0(key, "_prior")),
        shiny::tags$p(
          class = "hint",
          "Elicited beliefs, before new observations. The wider prediction also includes variation between measurements."
        )
      )
    },
    if (!is.null(p)) {
      shiny::tagList(
        shiny::tags$details(
          shiny::tags$summary("Review details"),
          inquiry_fields(p$claim),
          inquiry_field("Ideas to consider; not adopted", p$changes$ideas),
          inquiry_prediction(p),
          inquiry_source_details(p)
        ),
        shiny::tags$p(
          class = "hint",
          "Apply adds a revision. It does not accept the interpretation as reviewed or adopt the suggested ideas."
        ),
        shiny::tags$div(
          class = "inquiry-chat-actions",
          shiny::actionButton(
            paste0(key, "_apply"),
            "Apply interpretation",
            class = "btn-primary"
          ),
          shiny::actionButton(paste0(key, "_edit"), "Correct"),
          shiny::actionButton(paste0(key, "_decline"), "Decline")
        )
      )
    } else {
      shiny::tags$p(role = "status", class = "hint", view$note)
    }
  )
}

inquiry_chat_cards <- function(
  input,
  output,
  session,
  proposal,
  record,
  running,
  act
) {
  cards <- shiny::reactiveVal(list())
  # Per card: its view, prior visual, observers and output IDs. A card's
  # outputs read only its own view and visual, which ignore identical values,
  # so a change re-renders only the cards it affects. Restore and reset
  # destroy the cards they drop.
  registered <- new.env(parent = emptyenv())
  inputs <- function() {
    list(
      entries = cards(),
      proposal = proposal(),
      record = record(),
      running = running()
    )
  }
  view_of <- function(key, x) {
    inquiry_card_view(key, x$entries, x$proposal, x$record, x$running)
  }
  # Read every input first, so this observer depends on them even while no
  # cards are registered.
  shiny::observe({
    x <- inputs()
    for (key in ls(registered)) {
      registered[[key]]$view(view_of(key, x))
      registered[[key]]$visual(x$entries[[key]]$visual)
    }
  })
  register <- function(key) {
    if (exists(key, registered, inherits = FALSE)) {
      return(invisible(NULL))
    }
    x <- shiny::isolate(inputs())
    view <- shiny::reactiveVal(view_of(key, x))
    visual <- shiny::reactiveVal(x$entries[[key]]$visual)
    output[[key]] <- shiny::renderUI(inquiry_card_ui(key, view()))
    prior <- bind_inquiry_prior(output, paste0(key, "_prior"), visual)
    actions <- lapply(c("apply", "edit", "decline"), function(selected_action) {
      button <- paste0(key, "_", selected_action)
      shiny::observeEvent(
        input[[button]],
        {
          if (!isTRUE(input[[button]] > 0)) {
            return()
          }
          tryCatch(
            {
              entries <- shiny::isolate(cards())
              entry <- entries[[key]]
              if (
                is.null(entry) ||
                  !identical(
                    inquiry_card_state(
                      entry,
                      shiny::isolate(proposal()),
                      shiny::isolate(record())
                    ),
                    "ready"
                  )
              ) {
                abort_suppose(
                  "This draft is no longer available. Review the current suggestion.",
                  "stale"
                )
              }
              same_request <- Filter(
                function(x) identical(x$request_id, entry$request_id),
                entries
              )
              if (!identical(utils::tail(names(same_request), 1), key)) {
                abort_suppose(
                  "Review the latest draft in this response.",
                  "stale"
                )
              }
              act(selected_action, entry$request_id)
            },
            error = function(e) {
              shiny::showNotification(
                cli::ansi_strip(conditionMessage(e)),
                type = "error"
              )
            }
          )
        },
        ignoreInit = TRUE
      )
    })
    registered[[key]] <- list(
      view = view,
      visual = visual,
      observers = c(actions, prior$observers),
      outputs = c(key, prior$outputs)
    )
    invisible(NULL)
  }
  unregister <- function(key) {
    card <- registered[[key]]
    for (observer in card$observers) {
      observer$destroy()
    }
    for (id in card$outputs) {
      output[[id]] <- NULL
    }
    rm(list = key, envir = registered)
    invisible(NULL)
  }
  decorate <- function(name, args, result, request_id, value) {
    if (
      !name %in%
        c(
          "propose_interpretation",
          "propose_normal_contrast",
          "preview_proposal"
        )
    ) {
      return(value)
    }
    entries <- shiny::isolate(cards())
    if (
      name != "propose_interpretation" &&
        any(vapply(
          entries,
          function(x) identical(x$request_id, request_id),
          logical(1)
        ))
    ) {
      return(value)
    }
    key <- paste0(
      "inquiry_decision_",
      object_id(list(request_id, args, length(entries) + 1L))
    )
    card <- list(
      key = key,
      request_id = request_id,
      wording = args$wording %||%
        if (is.list(result)) result$claim$wording else NULL
    )
    card$wording <- card$wording %||%
      utils::tail(shiny::isolate(record())$revisions, 1)[[1]]$claim$wording
    entries <- shiny::isolate(cards())
    entries[[key]] <- card
    cards(entries)
    register(key)
    ellmer::ContentToolResult(
      value = value,
      extra = list(
        display = shinychat::tool_result_display(
          title = "Review an interpretation",
          html = shiny::uiOutput(key),
          open = TRUE,
          show_request = FALSE
        )
      )
    )
  }
  restore <- function(entries) {
    entries <- entries %||% list()
    for (key in setdiff(ls(registered), names(entries))) {
      unregister(key)
    }
    cards(entries)
    lapply(names(entries), register)
    invisible(NULL)
  }
  decline <- function(request_id) {
    entries <- shiny::isolate(cards())
    for (key in names(entries)) {
      if (identical(entries[[key]]$request_id, request_id)) {
        entries[[key]]$outcome <- "declined"
      }
    }
    cards(entries)
  }
  shiny::observeEvent(proposal(), {
    p <- proposal()
    entries <- shiny::isolate(cards())
    matching <- names(Filter(
      function(x) identical(x$request_id, p$context$request_id),
      entries
    ))
    if (length(matching)) {
      key <- utils::tail(matching, 1)
      entries[[key]]$visual <- inquiry_prior_visual(p)
      cards(entries)
    }
  })
  list(
    decorate = decorate,
    entries = cards,
    restore = restore,
    decline = decline,
    registered = function() ls(registered)
  )
}
