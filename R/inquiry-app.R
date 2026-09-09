#' Open the conversation-first inquiry workbench
#'
#' Start with any problem or belief. The conversation develops a reviewable
#' interpretation with expectations, assumptions and unresolved questions.
#' Numerical modeling is optional and limited to implemented methods. Use
#' [suppose_example_app()] for the detailed temperature-model demonstration.
#' Without a chat or agent, a labeled local guide and record editor remain usable.
#' @param record Optional existing record or JSON path. Defaults to an empty conversation.
#' @param chat An ellmer Chat used as a provider/model configuration template, or
#'   a zero-argument function creating a fresh Chat per session. For example,
#'   `chat = ellmer::chat_openai()` or `chat = ellmer::chat_openai`.
#'   Object templates start with fresh history, tools, and callbacks; their system
#'   prompt is replaced by Suppose's. The supplied object is not modified.
#'   Use a constructor for custom Chat subclasses or session-specific resources.
#' @param agent_factory Advanced: a function creating a fresh Deputy Agent per
#'   session. Use [suppose_agent()] for the built-in setup.
#' @param chat_factory Compatibility argument for a Chat constructor. Prefer
#'   `chat = constructor`. Supply only one of `chat`, `chat_factory`, or
#'   `agent_factory`. Both Chat forms are wrapped in a Suppose Deputy Agent.
#' @param history_dir Directory for local conversation history, or `NULL` to disable.
#'   History is shared by sessions of this local app; use separate directories for
#'   separate users. Requires a connected agent.
#' @return A Shiny app object.
#' @export
suppose_app <- function(
  record = NULL,
  chat_factory = NULL,
  agent_factory = NULL,
  history_dir = getOption(
    "suppose.history_dir",
    file.path(getwd(), ".suppose", "conversations")
  ),
  chat = NULL
) {
  rlang::check_installed(c(
    "shiny",
    "bslib",
    "shinychat",
    "ggplot2",
    "patchwork",
    "ggdist",
    "plotly"
  ))
  if (is.character(record)) {
    record <- read_record(record)
  }
  if (!is.null(record)) {
    validate_record(record)
  }
  if (!is.null(chat)) {
    if (!is.null(chat_factory) || !is.null(agent_factory)) {
      abort_suppose("Supply only one of chat, chat_factory, or agent_factory.")
    }
    chat_factory <- inquiry_chat_factory(chat)
  }
  if (!is.null(chat_factory) && !is.function(chat_factory)) {
    abort_suppose("chat_factory must be a function or NULL.")
  }
  if (!is.null(agent_factory) && !is.function(agent_factory)) {
    abort_suppose("agent_factory must be a function or NULL.")
  }
  if (!is.null(agent_factory) && !is.null(chat_factory)) {
    abort_suppose("Supply agent_factory or chat_factory, not both.")
  }
  record_ui <- shiny::tags$div(
    class = "inquiry-record",
    shiny::uiOutput("form_notice"),
    shiny::uiOutput("proposal_card"),
    shiny::uiOutput("record_card"),
    shiny::uiOutput("model_card"),
    shiny::tags$details(
      shiny::tags$summary("Edit the interpretation yourself"),
      shiny::textInput("author", "Your name", "You"),
      shiny::textAreaInput("wording", "Belief or question", width = "100%"),
      shiny::textAreaInput(
        "target",
        "What would you observe or compare?",
        width = "100%"
      ),
      shiny::textAreaInput(
        "scope",
        "Who or what does this concern?",
        width = "100%"
      ),
      shiny::textInput("horizon", "Time horizon"),
      shiny::textInput("units", "Units, if relevant"),
      shiny::textAreaInput(
        "expectations",
        "Expectations (one per line)",
        width = "100%"
      ),
      shiny::textAreaInput(
        "assumptions",
        "Assumptions (one per line)",
        width = "100%"
      ),
      shiny::textAreaInput(
        "unresolved",
        "Open questions (one per line)",
        width = "100%"
      ),
      shiny::textInput(
        "edit_reason",
        "Reason for this revision",
        "Clarify the interpretation"
      ),
      shiny::actionButton("retain", "Retain this interpretation")
    ),
    shiny::uiOutput("review_controls"),
    judgment_ui("expectation"),
    expectation_check_ui("expectation_check"),
    model_reference_ui("model_reference"),
    measurement_import_ui("import"),
    observations_ui("measurements"),
    updates_ui("learning"),
    prospective_ui("prospective"),
    sensitivity_ui("sensitivity"),
    extension_ui("extension"),
    regression_ui("regression"),
    research_design_ui("design"),
    shiny::tags$details(
      shiny::tags$summary("Saved R analyses"),
      shiny::uiOutput("analyses")
    ),
    shiny::tags$details(
      shiny::tags$summary("History and conversation"),
      shiny::uiOutput("revision_picker"),
      shiny::uiOutput("review_details"),
      shiny::verbatimTextOutput("transcript")
    ),
    shiny::downloadButton("save", "Save conversation and record"),
    shiny::tags$p(
      class = "hint",
      shiny::textOutput("save_notice", inline = TRUE)
    ),
    shiny::fileInput(
      "reopen",
      "Reopen a saved conversation or record",
      accept = ".json"
    ),
    shiny::tags$div(role = "status", shiny::textOutput("reopen_status")),
    shiny::tags$details(
      shiny::tags$summary("Worked examples"),
      worked_examples_ui()
    )
  )
  page_style <- shiny::tags$head(shiny::tags$style(shiny::HTML(
    "shiny-chat-container{min-height:0;--shiny-chat-message-bg-assistant:transparent}
       .suppose-brand-mark{display:block;object-fit:contain;margin-bottom:20px}.worked-example-card{padding:16px 0;border-bottom:1px solid #dfd3e8}.worked-example-card h3{font-size:1.15rem}.welcome{max-width:650px;margin:0 auto;padding:30px 0 16px}
       .welcome .eyebrow{letter-spacing:.13em;font-size:.72rem;color:#79508d;text-transform:uppercase}
       .welcome h1{font:700 clamp(2.25rem,5vw,3.6rem)/1.08 var(--bs-font-sans-serif);letter-spacing:-.035em;margin:16px 0 22px}
       .welcome .intro{font-size:1.1rem;line-height:1.6;max-width:570px;color:#695775}
       .welcome .invitation{margin:24px 0 12px;font-size:.86rem;color:#695775}
       .chat-examples{display:flex;flex-wrap:wrap;gap:8px}.chat-examples .btn:hover{background:#eee5f8;border-color:#b7a0ea}.chat-examples .btn{color:#633b83;border:1px solid #d9c9eb;border-radius:20px;background:transparent;font-size:.85rem;padding:8px 14px}
       .inquiry-footer{display:flex;align-items:center;justify-content:space-between;gap:12px;width:100%;font-size:.8rem}
       .footer-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap}.footer-tools .btn{border:0;background:transparent;color:#695775;font-size:.8rem;padding:6px 8px;white-space:nowrap}
       .footer-tools .btn:hover{background:#eee5f8}.footer-status{color:#695775;max-width:58%;font-size:.75rem;line-height:1.35}
       .modal-dialog{margin:16px auto}.modal-content{max-height:calc(100dvh - 32px)}.modal-body{overflow-y:auto}.modal-header,.modal-footer{flex-shrink:0}.model-facts{display:flex;gap:24px;flex-wrap:wrap}.command-list{display:grid;gap:8px}.command-list .btn{text-align:left;display:flex;gap:18px;align-items:baseline}.command-list strong{min-width:105px}.command-list span{white-space:normal}.footer-tools #open_models{max-width:180px;overflow:hidden;text-overflow:ellipsis}.inquiry-record{padding:10px 6px 24px}.inquiry-record h2{font-size:1.4rem}.inquiry-record .btn{margin:4px 5px 4px 0}
       .inquiry-record details{margin:16px 0}.inquiry-record summary{font-weight:600}.inquiry-record blockquote{border-left:3px solid #b7a0ea;background:#fff5db;padding:10px 14px;border-radius:0 8px 8px 0}.hint{font-size:.87rem;color:#695775}
       .record-field{margin-bottom:1rem}.record-field h3{font:600 .9rem system-ui;margin:0 0 .3rem}
       .inquiry-chat-actions{display:flex;flex-wrap:wrap;gap:.5rem;margin-top:.75rem}.inquiry-chat-decision details{margin:.75rem 0}
       .record-field p{margin:0;white-space:pre-wrap;overflow-wrap:anywhere}.proposal{border-left:3px solid #b74d08;padding-left:14px}
       pre{white-space:pre-wrap;overflow-wrap:anywhere}textarea{min-height:60px}
       :focus-visible{outline:3px solid #b74d08!important;outline-offset:3px}
       @media(max-width:700px){.suppose-brand-mark{width:64px;height:74px;margin-bottom:12px}.welcome h1{font-size:2rem;margin:12px 0 16px}.welcome .intro{font-size:1rem;line-height:1.5}.welcome .invitation{margin:16px 0 10px}.modal .nav-tabs .nav-link{padding:.5rem .6rem}shiny-chat-container{padding:0 12px 8px}.welcome{padding:16px 4px}.inquiry-footer{flex-direction:column;align-items:stretch;gap:4px}.footer-status{max-width:none}}"
  )))
  ui <- shinychat::page_chat(
    "Suppose",
    id = "inquiry",
    window_title = "Suppose | Talk through a problem",
    toolbar_global = NULL,
    sidebar = TRUE,
    theme = suppose_theme(),
    allow_attachments = FALSE,
    placeholder = "I have a hunch that\u2026",
    greeting = shiny::tags$div(
      class = "welcome",
      suppose_brand_mark(),
      shiny::tags$p(class = "eyebrow", "A space to think things through"),
      shiny::tags$h1(
        "What if your hunch",
        shiny::tags$br(),
        "is onto something?"
      ),
      shiny::tags$p(
        class = "intro",
        "Bring a question you keep returning to, a decision you're weighing, or something you suspect might be true. Together, we'll make it clearer\u2014and work out what could change your mind."
      ),
      shiny::tags$p(
        class = "invitation",
        "Start with your own words, or borrow a starting point."
      ),
      shiny::tags$div(
        class = "chat-examples",
        shiny::actionButton("example_work", "Rethink how we work"),
        shiny::actionButton("example_service", "Explore an idea"),
        shiny::actionButton("example_research", "Untangle a question")
      ),
      shiny::tags$p(
        shiny::actionButton(
          "open_examples_welcome",
          "Learn with worked examples"
        )
      )
    ),
    drawer = shinychat::chat_drawer(
      record_ui,
      title = "Your developing record",
      width = 440,
      open = FALSE
    ),
    footer = shiny::tags$div(
      class = "inquiry-footer",
      shiny::tags$div(
        class = "footer-tools",
        shiny::actionButton(
          "open_models",
          shiny::textOutput("model_label", inline = TRUE)
        ),
        shiny::actionButton(
          "open_commands",
          "/",
          title = "Inquiry commands",
          `aria-label` = "Inquiry commands"
        ),
        shiny::actionButton("open_tools", "Tools"),
        shiny::actionButton("open_examples", "Examples"),
        shiny::actionButton(
          "toggle_record",
          "Record",
          icon = shiny::icon("file-lines")
        )
      ),
      shiny::tags$div(
        class = "footer-status",
        role = "status",
        `aria-live` = "polite",
        shiny::textOutput("status")
      )
    )
  )
  ui <- shiny::tagList(
    page_style,
    shiny::tags$head(
      shiny::tags$style(
        "button[aria-label='Edit message'], .shiny-chat-sibling-nav {display:none!important;}"
      ),
      shiny::tags$script(shiny::HTML(
        "$(document).on('shiny:inputchanged', function(e) { if (['inquiry_message_edit','inquiry_message_navigate'].includes(e.name)) e.preventDefault(); }); $(document).on('shiny:connected', function() { Shiny.addCustomMessageHandler('suppose-open-section', function(id) { if (!['import-panel','prospective-panel','measurements-panel','sensitivity-panel','extension-panel','regression-panel','design-panel'].includes(id)) return; const panel = document.getElementById(id); if (panel) { panel.open = true; setTimeout(function() { panel.scrollIntoView({block: 'start'}); }, 250); } }); });"
      ))
    ),
    ui
  )
  shiny::shinyApp(ui, function(input, output, session) {
    learning <- worked_example_session(
      shiny::isolate(session$clientData$url_search),
      record,
      history_dir
    )
    inquiry_server(
      input,
      output,
      session,
      learning$record,
      chat_factory,
      agent_factory,
      learning$history_dir
    )
  })
}

inquiry_field <- function(label, value) {
  if (is.null(value) || !length(value) || !any(nzchar(value))) {
    return(NULL)
  }
  shiny::tags$div(
    class = "record-field",
    shiny::tags$h3(label),
    shiny::tags$p(paste(value, collapse = "\n"))
  )
}

inquiry_fields <- function(c) {
  shiny::tagList(
    inquiry_field("Belief or question", c$wording),
    inquiry_field("What to observe or compare", c$target),
    inquiry_field("Scope", c$scope),
    inquiry_field("Units", c$units),
    inquiry_field("Time horizon", c$horizon),
    inquiry_field("Expectations", c$expectations),
    inquiry_field("Assumptions", c$assumptions),
    inquiry_field("Open questions", c$unresolved)
  )
}

inquiry_prediction <- function(p, plot_id = NULL) {
  if (is.null(p$prediction)) {
    return(shiny::tags$p(
      class = "hint",
      "No numerical model attached. You can review the interpretation on its own."
    ))
  }
  d <- p$prediction$summary$mean_difference
  b <- p$prediction$summary$batch_difference
  units <- p$claim$units
  shiny::tagList(
    if (!is.null(plot_id)) inquiry_prior_output(plot_id),
    shiny::tags$p(sprintf(
      "Expected mean difference: %.2f %s. Central 90%% interval: %.2f to %.2f %s.",
      d$mean,
      units,
      d$lower,
      d$upper,
      units
    )),
    if (!is.null(d$probability_above)) {
      shiny::tags$p(sprintf(
        "Prior probability above %s %s: %.1f%%.",
        p$claim$threshold,
        units,
        100 * d$probability_above
      ))
    },
    shiny::tags$p(sprintf(
      "Two future measurements: central 90%% interval %.2f to %.2f %s.",
      b$lower,
      b$upper,
      units
    )),
    inquiry_field("Model assumptions", p$candidate$assumptions),
    shiny::tags$p(sprintf(
      "Correlation of uncertain means: %s. Known measurement SDs: %s %s.",
      p$candidate$correlation,
      paste(p$candidate$batch_sd, collapse = ", "),
      units
    )),
    shiny::tags$p(
      class = "hint",
      "These are consequences of the stated model, not observations or evidence that the belief is true."
    )
  )
}

inquiry_server <- function(
  input,
  output,
  session,
  initial = NULL,
  chat_factory = NULL,
  agent_factory = NULL,
  history_dir = NULL
) {
  current <- shiny::reactiveVal(initial)
  proposal <- shiny::reactiveVal(NULL)
  forms <- shiny::reactiveVal(list())
  extension_controller <- sensitivity_controller <- regression_controller <- import_controller <- design_controller <- NULL
  editing_proposal <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal(
    "Your record takes shape as we talk."
  )
  reopen_status <- shiny::reactiveVal(NULL)
  output$reopen_status <- shiny::renderText(reopen_status())
  transcript <- shiny::reactiveVal(list())
  runtime_activity <- shiny::reactiveVal(inquiry_saved_activity(initial))
  latest <- shiny::reactive({
    if (is.null(current())) NULL else utils::tail(current()$revisions, 1)[[1]]
  })
  visible <- shiny::reactive({
    if (is.null(current())) {
      return(NULL)
    }
    n <- suppressWarnings(as.integer(input$revision))
    if (
      length(n) != 1 || is.na(n) || n < 1 || n > length(current()$revisions)
    ) {
      return(latest())
    }
    current()$revisions[[n]]
  })
  safely <- function(code) {
    tryCatch(force(code), error = function(e) {
      status(cli::ansi_strip(conditionMessage(e)))
      shiny::showNotification(
        cli::ansi_strip(conditionMessage(e)),
        type = "error"
      )
      invisible(NULL)
    })
  }
  client <- safely({
    agent <- if (!is.null(agent_factory)) {
      agent_factory()
    } else if (!is.null(chat_factory)) {
      suppose_agent(chat_factory())
    } else {
      NULL
    }
    if (!is.null(agent) && !inherits(agent, "Agent")) {
      abort_suppose("agent_factory must return a fresh Deputy Agent.", "agent")
    }
    agent
  })
  assistant <- new_proposal_session(
    function() shiny::isolate(current()),
    function(p) proposal(p),
    model = if (is.null(client)) "local-guide" else client$get_model(),
    provider = if (is.null(client)) "local" else "deputy",
    general = TRUE,
    result_display = function(...) decision_cards$decorate(...),
    get_form_state = function() {
      shiny::isolate(list(
        extension = if (is.null(extension_controller)) {
          NULL
        } else {
          extension_controller$form_state()
        },
        sensitivity = if (is.null(sensitivity_controller)) {
          NULL
        } else {
          sensitivity_controller$form_state()
        },
        import = if (is.null(import_controller)) {
          NULL
        } else {
          import_controller$form_state()
        },
        design = if (is.null(design_controller)) {
          NULL
        } else {
          design_controller$form_state()
        },
        regression = if (is.null(regression_controller)) {
          NULL
        } else {
          regression_controller$form_state()
        }
      ))
    },
    publish_form = function(draft) {
      saved <- shiny::isolate(forms())
      saved[[draft$form]] <- draft
      forms(saved)
      shinychat::chat_drawer_show("inquiry", session = session)
      session$sendCustomMessage(
        "suppose-open-section",
        paste0(draft$form, "-panel")
      )
    }
  )
  assistant$messages <- initial$conversation %||%
    latest_initial_messages(initial)
  transcript(assistant$messages)
  busy <- function() {
    if (
      assistant$phase == "running" ||
        (!is.null(chat) && chat$status() == "streaming")
    ) {
      abort_suppose(
        "Finish or cancel the response before changing the record.",
        "busy"
      )
    }
  }
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
  shiny::observeEvent(input$toggle_record, {
    shinychat::chat_drawer_toggle("inquiry")
  })
  shiny::observe({
    label <- if (!is.null(proposal())) {
      "Record \u00b7 suggestion ready"
    } else {
      "Record"
    }
    shiny::updateActionButton(session, "toggle_record", label = label)
  })
  model_version <- shiny::reactiveVal(0L)
  output$model_label <- shiny::renderText({
    model_version()
    if (is.null(client)) {
      "Local guide"
    } else if (grepl("muse", client$get_model())) {
      "Muse \u25be"
    } else {
      paste(client$get_model(), "\u25be")
    }
  })
  output$status <- shiny::renderText(status())
  chat <- NULL
  if (!is.null(client)) {
    client$set_system_prompt(inquiry_prompt())
    if (length(assistant$messages)) {
      client$set_turns(lapply(assistant$messages, function(m) {
        ellmer::Turn(m$role, m$text)
      }))
    }
  }
  shiny::observeEvent(
    input$inquiry_user_input,
    safely({
      message <- input$inquiry_user_input
      if (is.list(message)) {
        message <- paste(
          vapply(
            message,
            function(m) if (is.character(m)) m else ellmer::contents_text(m),
            character(1)
          ),
          collapse = "\n"
        )
      }
      check_text(message, "message")
      if (is.null(current())) {
        current(elicitation_record(
          claim(message, input$author %||% "You"),
          "My inquiry"
        ))
      }
      id <- assistant$begin(message)
      bind_analysis_capture(id)
      transcript(assistant$messages)
      if (!is.null(client)) {
        assistant$request$runtime_previous_id <- client$last_run()$run_id
        extras <- if (is.function(client$inquiry_extra_tools)) {
          client$inquiry_extra_tools()
        } else {
          list()
        }
        client$set_tools(c(
          assistant$tools(id),
          extras
        ))
        client$set_system_prompt(inquiry_context_prompt(
          client$get_system_prompt(),
          inquiry_context_summary(assistant$request)
        ))
        status(
          "Thinking through your question. Suggestions will appear for review when the response finishes."
        )
      } else {
        c <- latest()$claim
        question <- if (is.null(c$target)) {
          "What would you observe or compare to tell whether this belief holds?"
        } else if (is.null(c$scope)) {
          "Who or what does this concern, and under what circumstances?"
        } else {
          "What evidence would make you reconsider this belief?"
        }
        response <- paste(
          "Local guide: I saved your message. A model is not connected, so I haven't interpreted it automatically.",
          question,
          "You can organize your answer in 'Edit the interpretation yourself'."
        )
        assistant$finish(id, response)
        transcript(assistant$messages)
        shinychat::chat_append("inquiry", response)
        status(
          "Message retained. Use the editor to organize your interpretation, or connect a model for conversational help."
        )
      }
    }),
    priority = 100
  )
  capture_activity <- function() {
    run <- client$last_run()
    if (
      !is.null(run) &&
        !identical(run$run_id, assistant$request$runtime_previous_id)
    ) {
      runtime_activity(inquiry_run_activity(client))
    }
  }
  decision_cards <- inquiry_chat_cards(
    input,
    output,
    session,
    proposal,
    current,
    running = function() {
      transcript()
      assistant$phase == "running"
    },
    act = function(action, request_id) change_proposal(action, request_id)
  )
  bind_chat <- function() {
    chat <<- shinychat::chat_server(
      "inquiry",
      client,
      history = inquiry_history_options(history_dir)
    )
    if (!is.null(history_dir)) {
      chat$history$on_save(function(values) {
        values$suppose <- encode_inquiry_history(
          shiny::isolate(current()),
          shiny::isolate(proposal()),
          assistant$messages,
          shiny::isolate(runtime_activity()),
          shiny::isolate(decision_cards$entries()),
          shiny::isolate(forms())
        )
        values
      })
      chat$history$on_restore(function(values) {
        state <- decode_inquiry_history(values$suppose)
        forms(state$forms %||% list())
        assistant$reset()
        assistant$messages <- state$messages
        assistant$pending <- state$proposal
        current(state$record)
        proposal(state$proposal)
        editing_proposal(NULL)
        runtime_activity(
          state$activity %||%
            inquiry_saved_activity(state$record, state$proposal)
        )
        decision_cards$restore(state$cards)
        # Restore after record-lineage observers clear the previous form state.
        session$onFlushed(
          function() {
            shiny::isolate({
              if (!is.null(state$forms$extension)) {
                extension_controller$restore(state$forms$extension)
              }
              if (!is.null(state$forms$sensitivity)) {
                sensitivity_controller$restore(state$forms$sensitivity)
              }
              if (!is.null(state$forms$regression)) {
                regression_controller$restore(state$forms$regression)
              } else if (length(state$record$predictors)) {
                regression_controller$restore_settings()
              }
              if (!is.null(state$forms$design)) {
                design_controller$restore(state$forms$design)
              }
              if (!is.null(state$forms$import)) {
                import_controller$restore(state$forms$import)
              }
            })
          },
          once = TRUE
        )
        transcript(assistant$messages)
        reset_runtime()
        status(
          "Conversation and developing record restored. R starts fresh; saved results remain available."
        )
      })
      for (event in c(
        "inquiry_history_new",
        "inquiry_history_select",
        "inquiry_history_delete"
      )) {
        local({
          name <- event
          shiny::observeEvent(
            input[[name]],
            {
              if (assistant$phase == "running") {
                shiny::freezeReactiveValue(input, name)
                shiny::showNotification(
                  "Finish or cancel the response before switching conversations."
                )
              }
            },
            priority = 200
          )
        })
      }
      previous_id <- NULL
      shiny::observe(
        {
          id <- chat$history$conversation_id()
          if (is.null(id) && !is.null(previous_id)) {
            assistant$reset()
            forms(list())
            current(NULL)
            proposal(NULL)
            editing_proposal(NULL)
            transcript(list())
            runtime_activity(NULL)
            decision_cards$restore(NULL)
            reset_runtime()
            status("Your record takes shape as we talk.")
          }
          previous_id <<- id
        },
        priority = 100
      )
      shiny::observe(
        {
          current()
          proposal()
          transcript()
          runtime_activity()
          decision_cards$entries()
          forms()
          if (
            assistant$phase != "running" &&
              !is.null(shiny::isolate(chat$history$conversation_id()))
          ) {
            safely(shiny::isolate(chat$history$save()))
          }
        },
        priority = -100
      )
    }
    shiny::observeEvent(
      chat$last_turn(),
      safely({
        if (assistant$phase != "running") {
          return()
        }
        run <- client$last_run()
        capture_activity()
        if (is.null(run) || !isTRUE(deputy::result_is_success(run))) {
          assistant$cancel("stopped")
          transcript(assistant$messages)
          status(
            "The agent stopped before completing this response. No incomplete proposal was applied."
          )
          return()
        }
        tryCatch(
          assistant$finish(
            assistant$request$id,
            ellmer::contents_text(chat$last_turn()),
            execution = deputy_run_receipt(client)
          ),
          error = function(e) {
            assistant$cancel("failed")
            stop(e)
          }
        )
        transcript(assistant$messages)
        status(
          if (length(assistant$request$form_drafts)) {
            "Chat prepared form values and a preview. Review the suggested assumptions in the open Record panel."
          } else if (is.null(proposal())) {
            "No record suggestion was created for this response. Your retained interpretation is unchanged."
          } else if (identical(proposal()$id, assistant$request$previous$id)) {
            "The existing suggestion is unchanged. Review it with the Record button."
          } else {
            "A proposed interpretation is ready for review. Apply it only if it expresses your meaning."
          }
        )
      })
    )
    shiny::observeEvent(chat$last_error(), {
      capture_activity()
      assistant$cancel("failed")
      transcript(assistant$messages)
      status(
        "The model response failed. No incomplete suggestion was applied. Send your message again to retry, or use the editor."
      )
    })
    shiny::observeEvent(
      input$inquiry_cancel,
      {
        assistant$cancel()
        transcript(assistant$messages)
        status("Response cancelled. Incomplete suggestions were discarded.")
      },
      priority = 100
    )
  }
  if (!is.null(client)) {
    bind_chat()
  }
  switch_agent <- function(new_agent, preserve_session = TRUE) {
    busy()
    if (!inherits(new_agent, "Agent")) {
      abort_suppose("The selected client must be a Deputy Agent.", "agent")
    }
    if (!is.null(client) && preserve_session) {
      transfer_inquiry_session(client, new_agent)
    } else {
      new_agent$set_system_prompt(inquiry_prompt())
      new_agent$set_turns(lapply(assistant$messages, function(m) {
        ellmer::Turn(m$role, m$text)
      }))
    }
    if (!is.null(chat)) {
      chat$set_client(new_agent, sync = FALSE)
    }
    if (!is.null(client) && is.function(client$inquiry_close)) {
      client$inquiry_close()
    }
    client <<- new_agent
    assistant$set_model(client$get_model(), "deputy")
    if (is.null(chat)) {
      bind_chat()
      controls$register(chat)
    }
    model_version(model_version() + 1L)
  }
  reset_runtime <- function() {
    shiny::isolate({
      config <- inquiry_agent_config(client)
      if (!is.null(config)) {
        config$conversation_id <- basename(tempfile("conversation_"))
        switch_agent(
          client$inquiry_reconfigure(config),
          preserve_session = FALSE
        )
      }
    })
  }
  remove_analysis_observer <- NULL
  bind_analysis_capture <- function(id) {
    if (is.function(remove_analysis_observer)) {
      remove_analysis_observer()
    }
    if (is.null(client)) {
      return(invisible(NULL))
    }
    owner <- client
    base <- assistant$request$base
    prompt <- utils::tail(assistant$messages, 1)[[1]]$text
    remove_analysis_observer <<- owner$on_tool_result(function(result) {
      execution <- result@extra$deputy_r
      if (
        is.null(execution) ||
          !identical(owner, client) ||
          !identical(assistant$request$id, id) ||
          !identical(
            proposal_basis_id(shiny::isolate(current())),
            proposal_basis_id(base)
          )
      ) {
        return(invisible(NULL))
      }
      current(record_analysis(
        shiny::isolate(current()),
        execution,
        source_prompt = prompt,
        model = owner$get_model(),
        request_id = id
      ))
    })
  }
  session$onSessionEnded(function() {
    if (is.function(remove_analysis_observer)) {
      remove_analysis_observer()
    }
    if (!is.null(client) && is.function(client$inquiry_close)) {
      client$inquiry_close()
    }
  })
  output$analyses <- shiny::renderUI(analysis_inventory_ui(current()))
  controls <- inquiry_controls(
    input,
    output,
    session,
    current_agent = function() {
      model_version()
      client
    },
    switch_agent = switch_agent,
    busy = busy,
    status = status,
    open_tools = function() tools_panel$open(),
    open_extension = function() {
      shinychat::chat_drawer_show("inquiry", session = session)
      session$sendCustomMessage("suppose-open-section", "extension-panel")
    },
    open_design = function() {
      shinychat::chat_drawer_show("inquiry", session = session)
      session$sendCustomMessage("suppose-open-section", "design-panel")
    },
    open_regression = function() {
      shinychat::chat_drawer_show("inquiry", session = session)
      session$sendCustomMessage("suppose-open-section", "regression-panel")
    },
    open_sensitivity = function() {
      shinychat::chat_drawer_show("inquiry")
      session$sendCustomMessage("suppose-open-section", "sensitivity-panel")
    },
    open_test = function() {
      shinychat::chat_drawer_show("inquiry")
      session$sendCustomMessage("suppose-open-section", "prospective-panel")
    }
  )
  tools_panel <- inquiry_tools_server(
    input,
    output,
    session,
    current_agent = function() {
      model_version()
      client
    },
    available_tools = function() {
      model_version()
      inquiry_agent_tools(client, assistant)
    },
    configure = function(config) {
      busy()
      switch_agent(client$inquiry_reconfigure(config))
    },
    submit = function(message, send_now) {
      chat$update_user_input(value = message, submit = send_now, focus = TRUE)
    },
    running = function() {
      !is.null(chat) && identical(chat$status(), "streaming")
    },
    activity = runtime_activity,
    busy = busy,
    status = status
  )
  if (!is.null(chat)) {
    controls$register(chat)
  }
  restore_chat <- function() {
    if (!is.null(chat)) {
      chat$clear()
    } else {
      shinychat::chat_clear("inquiry")
    }
    for (m in assistant$messages) {
      shinychat::chat_append("inquiry", m$text, role = m$role)
    }
    if (!is.null(client)) {
      client$set_turns(lapply(assistant$messages, function(m) {
        ellmer::Turn(m$role, m$text)
      }))
    }
  }
  shiny::observeEvent(
    TRUE,
    {
      if (length(assistant$messages)) restore_chat()
    },
    once = TRUE
  )
  for (nm in c("work", "service", "research")) {
    local({
      example <- nm
      shiny::observeEvent(input[[paste0("example_", example)]], {
        value <- switch(
          example,
          work = "I think fewer recurring meetings would help our team finish work sooner. How could we examine that?",
          service = "I think customers would pay for help migrating their data. Which assumptions should I examine first?",
          research = "I think longer exposure changes the response, but I am not sure whether I mean an average effect or more variation."
        )
        shinychat::update_chat_user_input(
          "inquiry",
          value = value,
          focus = TRUE
        )
      })
    })
  }
  show_examples <- function() {
    shiny::showModal(shiny::modalDialog(
      worked_examples_ui(),
      title = "Learn with worked examples",
      size = "l",
      easyClose = TRUE,
      footer = shiny::modalButton("Back to my conversation")
    ))
  }
  shiny::observeEvent(input$open_examples, show_examples())
  shiny::observeEvent(input$open_examples_welcome, show_examples())
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
      decision_cards$decline(p$context$request_id)
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
  expectation_check_server("expectation_check", current)
  model_reference_server(
    "model_reference",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before recording a model relationship."
        )
      }
    },
    author = function() input$author %||% "You"
  )
  judgment_server(
    "expectation",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before retaining an expectation."
        )
      }
    },
    author = function() input$author %||% "You"
  )
  observations_server("measurements", current, function() {
    busy()
    if (!is.null(proposal())) {
      abort_suppose(
        "Apply or decline the pending suggestion before importing measurements."
      )
    }
  })
  updates_server("learning", current, function() {
    busy()
    if (!is.null(proposal())) {
      abort_suppose(
        "Apply or decline the pending suggestion before updating the prior."
      )
    }
  })
  clear_form <- function(name) {
    saved <- shiny::isolate(forms())
    saved[[name]] <- NULL
    forms(saved)
  }
  output$form_notice <- shiny::renderUI({
    if (!length(forms())) {
      return(NULL)
    }
    shiny::tags$p(
      "Chat prepared form suggestions. Review or edit them below; they are not retained scientific decisions."
    )
  })
  import_controller <- measurement_import_server(
    "import",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before importing this table."
        )
      }
    },
    draft = shiny::reactive(forms()$import),
    retained = function() clear_form("import")
  )
  design_controller <- research_design_server(
    "design",
    current,
    guard = function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before reviewing research designs."
        )
      }
    },
    draft = shiny::reactive(forms()$design),
    author = function() input$author %||% "You",
    retained = function() clear_form("design")
  )
  regression_controller <- regression_server(
    "regression",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before reviewing regression models."
        )
      }
    },
    draft = shiny::reactive(forms()$regression),
    author = function() input$author %||% "You",
    retained = function() clear_form("regression")
  )
  extension_controller <- extension_server(
    "extension",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending interpretation before retaining a model alternative."
        )
      }
    },
    draft = shiny::reactive(forms()$extension),
    author = function() input$author %||% "You",
    retained = function() clear_form("extension")
  )
  sensitivity_controller <- sensitivity_server(
    "sensitivity",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending suggestion before reviewing sensitivity."
        )
      }
    },
    draft = shiny::reactive(forms()$sensitivity),
    retained = function() clear_form("sensitivity"),
    followup = function(message) {
      shinychat::update_chat_user_input(
        "inquiry",
        value = message,
        focus = TRUE,
        session = session
      )
      shinychat::chat_drawer_hide("inquiry", session = session)
    }
  )
  prospective_server(
    "prospective",
    current,
    function() {
      busy()
      if (!is.null(proposal())) {
        abort_suppose(
          "Apply or decline the pending suggestion before committing or assessing a test."
        )
      }
    },
    prepare_import = function(c) {
      shiny::updateTextInput(session, "measurements-source", value = c$source)
      shiny::updateTextInput(
        session,
        "measurements-protocol",
        value = c$protocol
      )
      shiny::updateTextInput(
        session,
        "measurements-units",
        value = c$prediction$units
      )
      shiny::updateTextInput(session, "measurements-target_units", value = "")
      shiny::updateNumericInput(session, "measurements-scale", value = 1)
      shiny::updateNumericInput(session, "measurements-offset", value = 0)
      shiny::updateSelectInput(
        session,
        "measurements-role",
        selected = "assessment"
      )
      shiny::updateSelectInput(
        session,
        "measurements-exposure",
        selected = "unknown"
      )
      shinychat::chat_drawer_show("inquiry")
      session$sendCustomMessage("suppose-open-section", "measurements-panel")
      status(
        "Choose the actual measurements CSV and declare its provenance. The committed source, protocol and units are filled in."
      )
    }
  )
  output$save_notice <- shiny::renderText({
    if (!is.null(history_dir) && !is.null(client)) {
      "Conversations, records and pending suggestions are saved automatically. Apply editor changes before leaving. Download a separate copy here."
    } else {
      "Save before closing. Unapplied suggestions and unsaved editor changes are not retained as revisions."
    }
  })
  output$save <- shiny::downloadHandler(
    filename = function() "suppose-conversation.json",
    content = function(path) {
      shiny::req(current())
      write_record(
        record_conversation(current(), assistant$messages),
        path,
        overwrite = TRUE
      )
    },
    contentType = "application/json"
  )
  shiny::observeEvent(
    input$reopen,
    tryCatch(
      {
        busy()
        if (
          !is.null(chat) &&
            !is.null(history_dir) &&
            !is.null(chat$history$conversation_id())
        ) {
          abort_suppose(
            "Start a new conversation before importing a saved record."
          )
        }
        out <- read_record(input$reopen$datapath)
        forms(list())
        assistant$reset()
        assistant$messages <- out$conversation %||% latest_initial_messages(out)
        current(out)
        decision_cards$restore(NULL)
        runtime_activity(inquiry_saved_activity(out))
        transcript(assistant$messages)
        restore_chat()
        reset_runtime()
        status(
          "Conversation and record reopened. Stored results were not recomputed."
        )
        reopen_status(status())
      },
      error = function(e) {
        message <- cli::ansi_strip(conditionMessage(e))
        status(message)
        reopen_status(message)
      }
    )
  )
  invisible(list(
    record = current,
    forms = forms,
    activity = runtime_activity,
    tools = tools_panel,
    cards = decision_cards,
    proposal = proposal,
    status = status,
    transcript = transcript,
    assistant = assistant,
    controls = controls,
    switch_agent = switch_agent,
    reset_runtime = reset_runtime,
    client = function() client
  ))
}

latest_initial_messages <- function(record) {
  if (is.null(record)) {
    return(list())
  }
  utils::tail(record$revisions, 1)[[
    1
  ]]$assistance$proposal$context$messages %||%
    list()
}


inquiry_change_summary <- function(old, proposed) {
  labels <- c(
    wording = "Belief or question",
    target = "Target",
    scope = "Scope",
    horizon = "Time horizon",
    units = "Units",
    expectations = "Expectations",
    assumptions = "Assumptions",
    unresolved = "Open questions"
  )
  changed <- names(labels)[
    !vapply(
      names(labels),
      function(nm) identical(old[[nm]], proposed[[nm]]),
      logical(1)
    )
  ]
  value <- function(x) {
    if (is.null(x) || !length(x)) "Not specified" else paste(x, collapse = "; ")
  }
  shiny::tags$details(
    shiny::tags$summary("What would change"),
    shiny::tags$ul(lapply(changed, function(nm) {
      shiny::tags$li(
        shiny::tags$strong(paste0(labels[[nm]], ": ")),
        value(old[[nm]]),
        " -> ",
        value(proposed[[nm]])
      )
    }))
  )
}
