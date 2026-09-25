# Guided questions: Deputy's ask_user tool rendered as answerable chat cards.
#
# The agent shows one to three multiple-choice questions and ends its turn. The
# person's choices return as their next ordinary chat message, so the answers
# are quotable user statements, persist with the conversation, and never leave
# a model run waiting on the browser.

inquiry_questions_available <- function() {
  requireNamespace("deputy", quietly = TRUE) &&
    "AskUserDeferred" %in% getNamespaceExports("deputy")
}

inquiry_question_prompt <- function() {
  if (!inquiry_questions_available()) {
    return(NULL)
  }
  paste(
    "Use ask_user to guide the person when their question is broad or ambiguous and choosing among a few",
    "distinct meanings, scopes, measures or directions would change your advice.",
    "Give a sentence or two of useful context first, then ask one to three short questions with two to four",
    "distinct options each. Each option label is a candidate framing written as the person could adopt it;",
    "its description says what choosing it implies. Options must not be invented facts about their situation,",
    "measurements, commitments or conclusions. The card always lets the person answer in their own words or skip.",
    "Do not ask about what the current record already settles, and do not ask again in the next reply.",
    "After ask_user succeeds, end your reply: the answers arrive as the person's next message. Treat a selected",
    "option as a statement the person adopted and their own words as a direct quote.",
    "Never use ask_user for numerical elicitation inputs such as intervals, SDs, correlations or thresholds;",
    "ask for numbers in prose so the person states them in their own words."
  )
}

inquiry_question_limit <- 2000L

# Options arrive from the browser, so accept only labels the model offered.
inquiry_question_selection <- function(question, selected) {
  labels <- vapply(question$options, function(o) o$label, character(1))
  selected <- as.character(unlist(selected %||% character()))
  selected <- selected[selected %in% labels]
  if (!isTRUE(question$multiSelect)) {
    selected <- utils::head(selected, 1)
  }
  selected
}

inquiry_question_answer_text <- function(questions, answers) {
  lines <- character()
  for (i in seq_along(questions)) {
    q <- questions[[i]]
    a <- if (i <= length(answers)) answers[[i]] else list()
    selected <- inquiry_question_selection(q, a$selected)
    own <- trimws(paste(a$own %||% "", collapse = " "))
    if (!length(selected) && !nzchar(own)) {
      next
    }
    parts <- c(
      if (length(selected)) paste0(paste(selected, collapse = "; "), "."),
      if (nzchar(own)) paste("In my own words:", own)
    )
    lines <- c(
      lines,
      paste0("- ", q$question, " ", paste(parts, collapse = " "))
    )
  }
  if (!length(lines)) {
    return(NULL)
  }
  paste(c("My answers to your questions:", lines), collapse = "\n")
}

# A card waits while the only message after its request is the reply that asked
# it. Message counts persist with the conversation, so this survives a restore.
inquiry_question_card_state <- function(card, messages, running) {
  switch(
    card$status %||% "open",
    answered = "answered",
    skipped = "Skipped. Reply in your own words whenever you like.",
    if (messages > card$messages + 1L) {
      "The conversation moved on; these questions are no longer waiting."
    } else if (running) {
      "Available after the response finishes."
    } else {
      "ready"
    }
  )
}

inquiry_question_card_ui <- function(key, card, state) {
  questions <- card$questions
  heading <- shiny::tags$p(class = "hint", "Questions to guide the next step")
  if (!identical(state, "ready")) {
    return(shiny::tags$section(
      class = "inquiry-chat-questions",
      `aria-label` = "Guiding questions",
      heading,
      shiny::tags$ul(lapply(questions, function(q) shiny::tags$li(q$question))),
      if (identical(state, "answered")) {
        shiny::tags$p(role = "status", class = "hint", "Answered in the chat.")
      } else {
        shiny::tags$p(role = "status", class = "hint", state)
      }
    ))
  }
  fields <- lapply(seq_along(questions), function(i) {
    q <- questions[[i]]
    id <- paste0(key, "_q", i)
    labels <- vapply(q$options, function(o) o$label, character(1))
    names <- lapply(q$options, function(o) {
      shiny::tags$span(
        shiny::tags$strong(o$label),
        if (nzchar(o$description %||% "")) {
          shiny::tags$span(class = "hint", paste0(" — ", o$description))
        }
      )
    })
    choices <- if (isTRUE(q$multiSelect)) {
      shiny::checkboxGroupInput(
        id,
        NULL,
        choiceNames = names,
        choiceValues = labels
      )
    } else {
      shiny::radioButtons(
        id,
        NULL,
        choiceNames = names,
        choiceValues = labels,
        selected = character()
      )
    }
    shiny::tags$fieldset(
      class = "inquiry-question",
      shiny::tags$legend(
        shiny::tags$span(class = "badge text-bg-light", q$header),
        " ",
        q$question
      ),
      choices,
      shiny::textInput(
        paste0(id, "_own"),
        "Or in my own words",
        placeholder = "Optional",
        width = "100%"
      )
    )
  })
  shiny::tags$section(
    class = "inquiry-chat-questions",
    `aria-label` = "Guiding questions",
    heading,
    fields,
    shiny::tags$div(
      class = "inquiry-chat-actions",
      shiny::actionButton(
        paste0(key, "_send"),
        "Send answers",
        class = "btn-primary"
      ),
      shiny::actionButton(paste0(key, "_skip"), "Skip")
    )
  )
}

inquiry_question_cards <- function(
  input,
  output,
  session,
  message_count,
  running,
  submit
) {
  cards <- shiny::reactiveVal(list())
  # Observer handles per card, destroyed when a restore or reset drops the card.
  registered <- new.env(parent = emptyenv())
  set_status <- function(key, status) {
    entries <- shiny::isolate(cards())
    entries[[key]]$status <- status
    cards(entries)
  }
  state_of <- function(key) {
    entry <- shiny::isolate(cards())[[key]]
    if (is.null(entry)) {
      return("missing")
    }
    inquiry_question_card_state(entry, message_count(), running())
  }
  register <- function(key) {
    if (exists(key, registered, inherits = FALSE)) {
      return(invisible(NULL))
    }
    output[[key]] <- shiny::renderUI({
      entry <- cards()[[key]]
      if (is.null(entry)) {
        return(NULL)
      }
      inquiry_question_card_ui(
        key,
        entry,
        inquiry_question_card_state(entry, message_count(), running())
      )
    })
    send <- shiny::observeEvent(
      input[[paste0(key, "_send")]],
      {
        if (!identical(state_of(key), "ready")) {
          shiny::showNotification(
            "These questions are not waiting for an answer.",
            type = "warning"
          )
          return()
        }
        questions <- shiny::isolate(cards())[[key]]$questions
        answers <- lapply(seq_along(questions), function(i) {
          id <- paste0(key, "_q", i)
          list(
            selected = input[[id]],
            own = substr(
              input[[paste0(id, "_own")]] %||% "",
              1,
              inquiry_question_limit
            )
          )
        })
        message <- inquiry_question_answer_text(questions, answers)
        if (is.null(message)) {
          shiny::showNotification(
            "Choose an option or write an answer, or skip these questions.",
            type = "warning"
          )
          return()
        }
        set_status(key, "answered")
        submit(message)
      },
      ignoreInit = TRUE
    )
    skip <- shiny::observeEvent(
      input[[paste0(key, "_skip")]],
      {
        if (identical(state_of(key), "ready")) {
          set_status(key, "skipped")
        }
      },
      ignoreInit = TRUE
    )
    registered[[key]] <- list(send, skip)
    invisible(NULL)
  }
  publish <- function(request_id, questions) {
    entries <- shiny::isolate(cards())
    if (
      any(vapply(
        entries,
        function(x) identical(x$request_id, request_id),
        logical(1)
      ))
    ) {
      ellmer::tool_reject(
        "Questions are already displayed for this reply. End your turn and wait for the answers."
      )
    }
    key <- paste0(
      "inquiry_questions_",
      object_id(list(request_id, questions, length(entries) + 1L))
    )
    entries[[key]] <- list(
      request_id = request_id,
      messages = shiny::isolate(message_count()),
      questions = questions,
      status = "open"
    )
    cards(entries)
    register(key)
    key
  }
  tool <- function(request_id) {
    if (!inquiry_questions_available()) {
      return(list())
    }
    deputy::tools_interactive(
      callback = function(questions, context) {
        key <- publish(request_id, questions)
        deputy::AskUserDeferred(
          extra = list(
            display = shinychat::tool_result_display(
              title = "Questions for you",
              html = shiny::uiOutput(key),
              open = TRUE,
              show_request = FALSE
            )
          )
        )
      },
      context = list(suppose_request = request_id)
    )
  }
  waiting <- function(request_id) {
    any(vapply(
      shiny::isolate(cards()),
      function(x) {
        identical(x$request_id, request_id) && identical(x$status, "open")
      },
      logical(1)
    ))
  }
  restore <- function(entries) {
    entries <- entries %||% list()
    for (key in setdiff(ls(registered), names(entries))) {
      lapply(registered[[key]], function(observer) observer$destroy())
      rm(list = key, envir = registered)
      output[[key]] <- NULL
    }
    cards(entries)
    lapply(names(entries), register)
    invisible(NULL)
  }
  list(
    tool = tool,
    waiting = waiting,
    entries = cards,
    restore = restore
  )
}
