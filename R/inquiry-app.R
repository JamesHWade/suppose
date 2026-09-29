# Suggested packages the workbench needs beyond Suppose's imports.
suppose_app_packages <- c(
  "shiny",
  "bslib",
  "shinychat",
  "ggplot2",
  "patchwork",
  "ggdist",
  "plotly"
)

#' Open the conversation-first inquiry workbench
#'
#' Start with any problem or belief. The conversation develops a reviewable
#' interpretation with expectations, assumptions and unresolved questions.
#' Numerical modeling is optional and limited to implemented methods. Use
#' [suppose_example_app()] for the detailed temperature-model demonstration.
#' Without a chat or agent, a labeled local guide and record editor remain usable.
#' @param model Optional snapshot from [inspect_model()] or
#'   [suppose_model_example()]. Opens the model-world walkthrough on startup.
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
#' @param history_dir Directory for saved conversation history, or `NULL` (the
#'   default, unless the `suppose.history_dir` option is set) to keep no
#'   history. Every session of the app can list, reopen and delete every
#'   conversation in this folder, so use it only for a local, single-user app,
#'   never for an app deployed for several people. Requires a connected agent.
#' @return A Shiny app object.
#' @export
suppose_app <- function(
  record = NULL,
  chat_factory = NULL,
  agent_factory = NULL,
  history_dir = getOption("suppose.history_dir"),
  chat = NULL,
  model = NULL
) {
  rlang::check_installed(suppose_app_packages)
  if (!is.null(model)) {
    validate_model_world(model)
  }
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
    shiny::actionButton("open_world_record", "Explore a model\u2019s world"),
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
    regression_test_ui("regression_test"),
    regression_sensitivity_ui("regression_sensitivity"),
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
        ),
        shiny::actionButton(
          "open_world_welcome",
          "Explore a model\u2019s world"
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
        shiny::actionButton("open_world", "Model worlds"),
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
  # Listed after the page so these styles follow the theme's.
  ui <- shiny::tagList(
    ui,
    suppose_dependency(
      "inquiry",
      stylesheet = "inquiry.css",
      script = "inquiry.js"
    )
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
      learning$history_dir,
      model = {
        query <- shiny::parseQueryString(shiny::isolate(
          session$clientData$url_search
        ))
        if (
          !is.null(query$suppose_world) &&
            query$suppose_world %in% c("linear", "curved", "waiting")
        ) {
          suppose_model_example(query$suppose_world)
        } else {
          model
        }
      }
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

# The reactive state the inquiry's controllers share.
inquiry_state <- function(input, initial) {
  current <- shiny::reactiveVal(initial)
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
  list(
    current = current,
    latest = latest,
    visible = visible,
    proposal = shiny::reactiveVal(NULL),
    editing_proposal = shiny::reactiveVal(NULL),
    forms = shiny::reactiveVal(list()),
    status = shiny::reactiveVal("Your record takes shape as we talk."),
    transcript = shiny::reactiveVal(list()),
    runtime_activity = shiny::reactiveVal(inquiry_saved_activity(initial)),
    model_version = shiny::reactiveVal(0L)
  )
}

inquiry_server <- function(
  input,
  output,
  session,
  initial = NULL,
  chat_factory = NULL,
  agent_factory = NULL,
  history_dir = NULL,
  model = NULL
) {
  if (!is.null(model)) {
    initial <- record_model_world(
      initial %||% model_world_inquiry(model),
      model
    )
  }
  state <- inquiry_state(input, initial)
  current <- state$current
  proposal <- state$proposal
  status <- state$status
  transcript <- state$transcript
  model_version <- state$model_version
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
  # The current Deputy agent and the chat bound to it; both change when the
  # person switches models or conversations.
  agent <- new.env(parent = emptyenv())
  agent$client <- safely(inquiry_new_agent(chat_factory, agent_factory))
  agent$chat <- NULL
  # Controllers created below, which earlier callbacks reach once they exist.
  decision_cards <- question_cards <- lifecycle <- controls <- NULL
  editor <- form_controls <- NULL
  assistant <- new_proposal_session(
    function() shiny::isolate(current()),
    function(p) proposal(p),
    model = if (is.null(agent$client)) {
      "local-guide"
    } else {
      agent$client$get_model()
    },
    provider = if (is.null(agent$client)) "local" else "deputy",
    general = TRUE,
    result_display = function(...) decision_cards$decorate(...),
    get_form_state = function() {
      if (is.null(form_controls)) {
        return(list())
      }
      shiny::isolate(form_controls$form_state())
    },
    publish_form = function(draft) {
      saved <- shiny::isolate(state$forms())
      saved[[draft$form]] <- draft
      state$forms(saved)
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
        (!is.null(agent$chat) && agent$chat$status() == "streaming")
    ) {
      abort_suppose(
        "Finish or cancel the response before changing the record.",
        "busy"
      )
    }
  }
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
  output$model_label <- shiny::renderText({
    model_version()
    if (is.null(agent$client)) {
      "Local guide"
    } else if (grepl("muse", agent$client$get_model())) {
      "Muse \u25be"
    } else {
      paste(agent$client$get_model(), "\u25be")
    }
  })
  output$status <- shiny::renderText(status())
  inquiry_prepare_agent(agent$client, assistant$messages)
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
      lifecycle$bind_analysis_capture(id)
      transcript(assistant$messages)
      client <- agent$client
      if (!is.null(client)) {
        assistant$request$runtime_previous_id <- client$last_run()$run_id
        extras <- if (is.function(client$inquiry_extra_tools)) {
          client$inquiry_extra_tools()
        } else {
          list()
        }
        client$set_tools(c(
          assistant$tools(id),
          question_cards$tool(id),
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
        c <- state$latest()$claim
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
    act = function(action, request_id) {
      editor$change_proposal(action, request_id)
    }
  )
  question_cards <- inquiry_question_cards(
    input,
    output,
    session,
    messages = function() {
      transcript()
      assistant$messages
    },
    running = function() {
      transcript()
      assistant$phase == "running"
    },
    submit = function(message) {
      agent$chat$update_user_input(value = message, submit = TRUE, focus = TRUE)
    }
  )
  conversation <- inquiry_history_binding(
    input,
    output,
    session,
    agent,
    state,
    history_dir,
    assistant,
    decision_cards,
    question_cards,
    busy,
    safely,
    capture_activity = function() lifecycle$capture_activity(),
    reset_runtime = function() lifecycle$reset_runtime(),
    restore_forms = function(saved, record) {
      form_controls$restore(saved, record)
    }
  )
  if (!is.null(agent$client)) {
    conversation$bind_chat()
  }
  lifecycle <- inquiry_agent_lifecycle(
    input,
    session,
    agent,
    state,
    assistant,
    busy,
    bind_chat = conversation$bind_chat,
    register_chat = function(chat) controls$register(chat),
    reset_world = function() {
      if (!is.null(form_controls)) {
        form_controls$world$reset()
      }
    }
  )
  output$analyses <- shiny::renderUI(analysis_inventory_ui(current()))
  controls <- inquiry_controls(
    input,
    output,
    session,
    current_agent = function() {
      model_version()
      agent$client
    },
    switch_agent = lifecycle$switch_agent,
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
      session$sendCustomMessage(
        "suppose-open-section",
        if (
          length(Filter(
            function(e) e$choice != "neither",
            current()$regressions
          ))
        ) {
          "regression_sensitivity-panel"
        } else {
          "sensitivity-panel"
        }
      )
    },
    open_test = function() {
      shinychat::chat_drawer_show("inquiry")
      session$sendCustomMessage(
        "suppose-open-section",
        if (
          length(Filter(
            function(e) e$choice != "neither",
            current()$regressions
          ))
        ) {
          "regression_test-panel"
        } else {
          "prospective-panel"
        }
      )
    }
  )
  tools_panel <- inquiry_tools_server(
    input,
    output,
    session,
    current_agent = function() {
      model_version()
      agent$client
    },
    available_tools = function() {
      model_version()
      inquiry_agent_tools(agent$client, assistant)
    },
    configure = function(config) {
      busy()
      lifecycle$switch_agent(agent$client$inquiry_reconfigure(config))
    },
    submit = function(message, send_now) {
      agent$chat$update_user_input(
        value = message,
        submit = send_now,
        focus = TRUE
      )
    },
    running = function() {
      !is.null(agent$chat) && identical(agent$chat$status(), "streaming")
    },
    activity = state$runtime_activity,
    busy = busy,
    status = status
  )
  if (!is.null(agent$chat)) {
    controls$register(agent$chat)
  }
  shiny::observeEvent(TRUE, conversation$restore_initial(), once = TRUE)
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
  show_world <- function() {
    shiny::showModal(shiny::modalDialog(
      form_controls$world$ui(),
      title = "The world implied by a model",
      size = "l",
      easyClose = FALSE,
      footer = shiny::modalButton("Back to my conversation")
    ))
  }
  for (id in c("open_world", "open_world_welcome", "open_world_record")) {
    local({
      button <- id
      shiny::observeEvent(input[[button]], show_world())
    })
  }
  saved_query <- shiny::parseQueryString(
    shiny::isolate(session$clientData$url_search) %||% ""
  )
  if (!is.null(model) && is.null(saved_query$shinychat_conversation_id)) {
    session$onFlushed(show_world, once = TRUE)
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
  editor <- inquiry_editor_server(
    input,
    output,
    session,
    state,
    assistant,
    busy,
    safely,
    decline = function(request_id) decision_cards$decline(request_id)
  )
  form_controls <- inquiry_forms_server(
    input,
    output,
    session,
    state,
    assistant,
    busy,
    model
  )
  conversation$serve_files()
  invisible(list(
    record = current,
    forms = state$forms,
    activity = state$runtime_activity,
    tools = tools_panel,
    cards = decision_cards,
    questions = question_cards,
    proposal = proposal,
    status = status,
    transcript = transcript,
    assistant = assistant,
    controls = controls,
    switch_agent = lifecycle$switch_agent,
    reset_runtime = lifecycle$reset_runtime,
    client = function() agent$client
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
