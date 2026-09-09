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
  registered <- new.env(parent = emptyenv())
  register <- function(card) {
    key <- card$key
    if (exists(key, registered, inherits = FALSE)) {
      return(invisible(NULL))
    }
    registered[[key]] <- TRUE
    output[[key]] <- shiny::renderUI({
      entries <- cards()
      entry <- entries[[key]]
      if (is.null(entry)) {
        return(NULL)
      }
      p <- proposal()
      state <- inquiry_card_state(entry, p, record())
      active <- identical(state, "ready") && !running()
      same_request <- Filter(
        function(x) identical(x$request_id, entry$request_id),
        entries
      )
      newest <- identical(utils::tail(names(same_request), 1), key)
      shiny::tags$section(
        class = "inquiry-chat-decision",
        `aria-label` = "Interpretation decision",
        shiny::tags$p(class = "hint", "Proposed interpretation"),
        shiny::tags$p(if (active && newest) p$claim$wording else entry$wording),
        if (!is.null(entry$visual)) {
          shiny::tagList(
            inquiry_prior_output(paste0(key, "_prior")),
            shiny::tags$p(
              class = "hint",
              "Elicited beliefs, before new observations. The wider prediction also includes variation between measurements."
            )
          )
        },
        if (active && newest) {
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
          shiny::tags$p(
            role = "status",
            class = "hint",
            if (running()) {
              "Available after the response finishes."
            } else if (!newest) {
              "Updated by a later draft in this response."
            } else {
              state
            }
          )
        }
      )
    })
    bind_inquiry_prior(
      output,
      paste0(key, "_prior"),
      shiny::reactive(cards()[[key]]$visual)
    )
    for (action in c("apply", "edit", "decline")) {
      local({
        selected_action <- action
        shiny::observeEvent(
          input[[paste0(key, "_", selected_action)]],
          {
            if (!isTRUE(input[[paste0(key, "_", selected_action)]] > 0)) {
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
    }
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
    register(card)
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
    cards(entries)
    lapply(entries, register)
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
    decline = decline
  )
}
