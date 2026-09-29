inquiry_tool_type <- function(type) {
  if (inherits(type, "ellmer::TypeBasic")) {
    return(type@type)
  }
  if (inherits(type, "ellmer::TypeArray")) {
    return("array")
  }
  if (inherits(type, "ellmer::TypeObject")) {
    return("object")
  }
  "string"
}

inquiry_tool_choices <- function(tools) {
  labels <- c(
    read_inquiry = "Read the inquiry",
    draft_measurements = "Prepare table import",
    draft_model_extension = "Prepare model extension review",
    draft_sensitivity = "Prepare sensitivity review",
    draft_regression = "Prepare regression priors",
    draft_research_design = "Prepare Bayesian research design",
    draft_regression_test = "Prepare future regression test",
    draft_regression_sensitivity = "Prepare regression sensitivity",
    propose_interpretation = "Draft an interpretation",
    propose_normal_contrast = "Propose a normal mean contrast",
    preview_proposal = "Preview the pending suggestion",
    ask_user = "Ask guiding questions",
    read_file = "Read a text file",
    read_markdown = "Read a Markdown file",
    read_csv = "Read a CSV file",
    list_files = "List files",
    glob_files = "Find files by pattern",
    grep_files = "Search file contents",
    write_file = "Write a file",
    edit_file = "Edit a file",
    multi_edit = "Make multiple file edits",
    run_r_code = "Run R code",
    run_bash = "Run a shell command",
    web_fetch = "Read a web page",
    web_search = "Search the web",
    deputy_read_tool_result = "Retrieve a large tool result"
  )
  choices <- names(tools)
  display <- unname(labels[choices])
  display[is.na(display)] <- choices[is.na(display)]
  stats::setNames(choices, display)
}

inquiry_tool_arguments_ui <- function(tool) {
  properties <- tool@arguments@properties
  defaults <- formals(tool)
  fields <- lapply(names(properties), function(name) {
    type <- properties[[name]]
    id <- paste0("tool_arg_", name)
    label <- paste(
      gsub("_", " ", name),
      if (isTRUE(type@required)) "*" else "(optional)"
    )
    default <- if (is.atomic(defaults[[name]])) defaults[[name]] else NULL
    input <- if (inquiry_tool_type(type) %in% c("number", "integer")) {
      shiny::numericInput(
        id,
        label,
        value = default,
        width = "100%"
      )
    } else if (inquiry_tool_type(type) == "boolean") {
      shiny::selectInput(
        id,
        label,
        c("Choose..." = "", "Yes" = "true", "No" = "false"),
        selected = if (is.null(default)) "" else tolower(as.character(default))
      )
    } else {
      shiny::textAreaInput(
        id,
        label,
        value = default %||% "",
        width = "100%",
        rows = if (name %in% c("code", "command", "content", "source_quote")) {
          4
        } else {
          2
        },
        placeholder = if (inherits(type, "ellmer::TypeArray")) {
          "One value per line"
        } else if (inherits(type, "ellmer::TypeObject")) {
          "JSON object"
        } else {
          NULL
        }
      )
    }
    shiny::tags$div(
      class = "tool-argument",
      input,
      shiny::tags$p(class = "hint", type@description %||% "")
    )
  })
  required <- vapply(
    properties,
    function(type) isTRUE(type@required),
    logical(1)
  )
  shiny::tagList(
    fields[required],
    if (!all(required)) {
      shiny::tags$details(
        shiny::tags$summary("Optional inputs"),
        fields[!required]
      )
    }
  )
}

inquiry_tool_arguments <- function(tool, values) {
  properties <- tool@arguments@properties
  out <- list()
  for (name in names(properties)) {
    type <- properties[[name]]
    value <- values[[paste0("tool_arg_", name)]]
    empty <- is.null(value) ||
      !length(value) ||
      anyNA(value) ||
      (is.character(value) && !any(nzchar(trimws(value))))
    if (empty) {
      if (isTRUE(type@required)) {
        abort_suppose(
          "Supply {.field {name}} before sending the tool request.",
          "tools"
        )
      }
      next
    }
    if (inquiry_tool_type(type) == "boolean") {
      if (!value %in% c("true", "false")) {
        abort_suppose("Choose Yes or No for {.field {name}}.", "tools")
      }
      value <- identical(value, "true")
    } else if (inherits(type, "ellmer::TypeArray")) {
      value <- as.list(strsplit(value, "\n", fixed = TRUE)[[1]])
    } else if (inherits(type, "ellmer::TypeObject")) {
      value <- jsonlite::fromJSON(value, simplifyVector = FALSE)
      if (!is.list(value) || is.null(names(value))) {
        abort_suppose("Supply a JSON object for {.field {name}}.", "tools")
      }
    } else if (inquiry_tool_type(type) %in% c("number", "integer")) {
      check_number(value, name)
      if (inquiry_tool_type(type) == "integer" && value != floor(value)) {
        abort_suppose("Supply a whole number for {.field {name}}.", "tools")
      }
    }
    out[[name]] <- value
  }
  out
}

inquiry_tool_request <- function(tool, arguments, purpose = "") {
  encoded <- as.character(jsonlite::toJSON(
    arguments,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE
  ))
  if (!length(arguments)) {
    encoded <- "{}"
  }
  paste(
    if (nzchar(trimws(purpose))) {
      purpose
    } else {
      paste("Please use", tool@name, "for this inquiry.")
    },
    paste0("Requested tool: ", tool@name),
    paste0("Use these inputs as stated:\n```json\n", encoded, "\n```"),
    if (!is.null(arguments$source_quote)) {
      paste0("My source words:\n", arguments$source_quote)
    },
    "Run the requested tool through Deputy and explain the actual result. If the inputs cannot be used, explain what needs to change. Do not apply or accept an interpretation on my behalf.",
    sep = "\n\n"
  )
}

inquiry_saved_activity <- function(record, proposal = NULL) {
  if (is.null(proposal) && length(record$revisions)) {
    proposal <- utils::tail(record$revisions, 1)[[1]]$assistance$proposal
  }
  runs <- proposal$context$runs
  if (!length(runs)) {
    return(NULL)
  }
  run <- utils::tail(runs, 1)[[1]]
  run$source <- "Saved interpretation"
  run
}

inquiry_run_activity <- function(agent) {
  receipt <- deputy_run_receipt(agent)
  if (is.null(receipt)) {
    return(NULL)
  }
  run <- agent$last_run()
  receipt$cost_usd <- if (isTRUE(run$cost$complete)) run$cost$total else NULL
  receipt$tools <- lapply(
    Filter(function(event) identical(event$type, "tool_end"), run$events),
    function(event) {
      list(
        name = event$tool_name,
        status = if (is.null(event$tool_error)) "Completed" else "Failed"
      )
    }
  )
  receipt
}

inquiry_tools_server <- function(
  input,
  output,
  session,
  current_agent,
  available_tools,
  configure,
  submit,
  running,
  activity,
  busy,
  status
) {
  safely <- function(code) {
    tryCatch(force(code), error = function(e) {
      shiny::showNotification(
        cli::ansi_strip(conditionMessage(e)),
        type = "error"
      )
    })
  }
  open_tools <- function() {
    agent <- shiny::isolate(current_agent())
    config <- inquiry_agent_config(agent)
    tools <- shiny::isolate(available_tools())
    limits <- S7::props(config$usage_limits) %||%
      if (!is.null(agent)) agent$usage_limits
    policy <- config$context_policy %||%
      if (!is.null(agent)) agent$context_policy
    bundles <- inquiry_tool_bundles()
    shiny::showModal(shiny::modalDialog(
      title = "Tools",
      size = "l",
      easyClose = TRUE,
      bslib::navset_tab(
        id = "tools_tab",
        bslib::nav_panel(
          "Tools",
          shiny::tags$p(
            "Turn on what you need, then ask in chat. Changes take effect immediately for this session."
          ),
          shiny::tags$div(
            class = "tool-capabilities",
            lapply(names(bundles), function(name) {
              bundle <- bundles[[name]]
              shiny::tags$div(
                class = "tool-capability",
                bslib::input_switch(
                  paste0("tools_enable_", name),
                  bundle$label,
                  value = name %in% (config$bundles %||% character())
                ),
                shiny::tags$p(class = "hint", bundle$detail)
              )
            })
          ),
          shiny::tags$p(
            class = "hint",
            "Inquiry tools are always on: read your record, draft an interpretation, propose a numerical comparison, and preview a suggestion."
          ),
          if (is.null(config)) {
            shiny::tags$p("Choose a conversation model to change tool access.")
          }
        ),
        bslib::nav_panel(
          "Request",
          shiny::tags$p(
            "Choose a tool, supply its inputs, and send the request to the conversation. Deputy governs execution; results and proposals appear in chat."
          ),
          shiny::selectInput(
            "tool_choice",
            "Tool",
            choices = inquiry_tool_choices(tools),
            selectize = FALSE,
            width = "100%"
          ),
          shiny::uiOutput("tool_description"),
          shiny::uiOutput("tool_arguments"),
          shiny::textAreaInput(
            "tool_purpose",
            "What are you trying to learn? (optional)",
            width = "100%",
            rows = 2
          ),
          shiny::actionButton(
            "tool_send",
            "Use in conversation",
            class = "btn-primary"
          ),
          shiny::actionButton("tool_insert", "Put request in composer"),
          if (is.null(agent)) {
            shiny::tags$p(
              class = "hint",
              "Choose a conversation model to run tool requests."
            )
          }
        ),
        bslib::nav_panel(
          "Settings",
          shiny::tags$p(
            "Adjust the working folder and response limits."
          ),
          shiny::textInput(
            "tools_working_dir",
            "Working folder",
            value = config$working_dir %||% getwd(),
            width = "100%"
          ),
          shiny::tags$p(
            class = "hint",
            "File writes are restricted to this folder. File reads use the local account's access. R and shell execution are not sandboxed: they can also write files and use the network. Enable them only for trusted work."
          ),
          shiny::tags$h3("Execution limits"),
          bslib::layout_columns(
            shiny::numericInput(
              "tools_max_requests",
              "Model requests per response",
              limits$max_requests,
              min = 1
            ),
            shiny::numericInput(
              "tools_max_calls",
              "Tool calls per response",
              limits$max_tool_calls,
              min = 1
            ),
            shiny::numericInput(
              "tools_max_tokens",
              "Total tokens per response (optional)",
              limits$max_total_tokens,
              min = 1
            ),
            shiny::numericInput(
              "tools_max_cost",
              "Estimated USD per response (optional)",
              limits$max_cost_usd,
              min = 0,
              step = 0.1
            ),
            col_widths = c(6, 6, 6, 6),
            fill = FALSE
          ),
          shiny::tags$p(
            class = "hint",
            "Blank limits are unset. Token and estimated-cost limits are checked after a model response and may overshoot by one response. A cost limit stops execution if the provider does not report cost."
          ),
          shiny::tags$details(
            shiny::tags$summary("Context and large results"),
            shiny::numericInput(
              "tools_context_tokens",
              "Compact context above this token estimate (blank disables)",
              policy$max_tokens,
              min = 1
            ),
            shiny::sliderInput(
              "tools_compact_to",
              "Target fraction after compaction",
              min = 0.1,
              max = 0.9,
              step = 0.1,
              value = policy$compact_to %||% 0.5
            ),
            shiny::numericInput(
              "tools_result_kib",
              "Keep tool results inline up to this many KiB (blank disables offloading)",
              if (is.null(policy$max_tool_result_bytes)) {
                NULL
              } else {
                policy$max_tool_result_bytes / 1024
              },
              min = 1
            ),
            shiny::tags$p(
              class = "hint",
              "Deputy can summarize older model context and keep large tool results in local files for retrieval. The visible conversation remains in history; its scientific record is unchanged."
            )
          ),
          if (is.null(config)) {
            shiny::tags$p(
              "This agent's configuration is managed by its factory. Connect a Suppose agent to change bundles and limits here."
            )
          },
          shiny::tags$p(
            class = "hint",
            "Access settings belong to this open session. Reopening a saved conversation does not grant additional tool access."
          )
        ),
        bslib::nav_panel(
          "Activity",
          shiny::uiOutput("tools_activity"),
          shiny::actionButton("tools_show_chat", "View results in conversation")
        )
      ),
      footer = shiny::tagList(
        shiny::modalButton("Close"),
        shiny::uiOutput("tools_settings_action", inline = TRUE)
      )
    ))
  }
  output$tools_settings_action <- shiny::renderUI({
    if (
      identical(input$tools_tab, "Settings") &&
        !is.null(inquiry_agent_config(current_agent()))
    ) {
      shiny::actionButton(
        "tools_apply",
        "Save settings",
        class = "btn-primary"
      )
    }
  })
  lapply(names(inquiry_tool_bundles()), function(name) {
    id <- paste0("tools_enable_", name)
    shiny::observeEvent(
      input[[id]],
      {
        config <- shiny::isolate(inquiry_agent_config(current_agent()))
        enabled <- name %in% (config$bundles %||% character())
        if (identical(isTRUE(input[[id]]), enabled)) {
          return()
        }
        tryCatch(
          {
            busy()
            if (is.null(config)) {
              abort_suppose(
                "Choose a conversation model before changing tool access.",
                "tools"
              )
            }
            config$bundles <- if (isTRUE(input[[id]])) {
              union(config$bundles, name)
            } else {
              setdiff(config$bundles, name)
            }
            configure(config)
            shiny::updateSelectInput(
              session,
              "tool_choice",
              choices = inquiry_tool_choices(available_tools()),
              selected = "read_inquiry"
            )
          },
          error = function(e) {
            bslib::update_switch(id, value = enabled, session = session)
            shiny::showNotification(
              cli::ansi_strip(conditionMessage(e)),
              type = "error"
            )
          }
        )
      },
      ignoreNULL = TRUE
    )
  })
  selected <- shiny::reactive(available_tools()[[input$tool_choice %||% ""]])
  output$tool_description <- shiny::renderUI({
    tool <- selected()
    if (is.null(tool)) {
      return(NULL)
    }
    metadata <- if ("tool_metadata" %in% getNamespaceExports("deputy")) {
      getExportedValue("deputy", "tool_metadata")(tool)
    } else {
      extra_names <- c(
        unlist(lapply(inquiry_tool_bundles(), `[[`, "tools")),
        "deputy_read_tool_result"
      )
      list(
        source = list(
          package = if (tool@name %in% extra_names) "Deputy" else "Suppose"
        )
      )
    }
    shiny::tagList(
      shiny::tags$p(tool@description),
      shiny::tags$p(
        class = "hint",
        paste(
          "Provided by",
          metadata$source$package %||% "Suppose",
          "\u00b7",
          tool@name
        )
      )
    )
  })
  output$tool_arguments <- shiny::renderUI({
    tool <- selected()
    if (!is.null(tool)) inquiry_tool_arguments_ui(tool)
  })
  send <- function(send_now) {
    safely({
      busy()
      if (is.null(current_agent())) {
        abort_suppose(
          "Choose a conversation model before using tools.",
          "tools"
        )
      }
      tool <- selected()
      if (is.null(tool)) {
        abort_suppose("Choose an available tool.", "tools")
      }
      args <- inquiry_tool_arguments(tool, shiny::reactiveValuesToList(input))
      message <- inquiry_tool_request(tool, args, input$tool_purpose %||% "")
      submit(message, send_now)
      shiny::removeModal()
    })
  }
  shiny::observeEvent(input$tool_send, send(TRUE))
  shiny::observeEvent(input$tool_insert, send(FALSE))
  shiny::observeEvent(
    input$tools_apply,
    safely({
      busy()
      config <- inquiry_agent_config(current_agent())
      if (is.null(config)) {
        abort_suppose("This agent is configured by its factory.", "tools")
      }
      optional <- function(value) {
        if (is.null(value) || !length(value) || is.na(value)) NULL else value
      }
      limits <- S7::props(config$usage_limits)
      limits$max_requests <- optional(input$tools_max_requests)
      limits$max_tool_calls <- optional(input$tools_max_calls)
      limits$max_total_tokens <- optional(input$tools_max_tokens)
      limits$max_cost_usd <- optional(input$tools_max_cost)
      config$usage_limits <- do.call(deputy::UsageLimits, unclass(limits))
      policy <- S7::props(config$context_policy)
      policy$max_tokens <- optional(input$tools_context_tokens)
      policy$compact_to <- input$tools_compact_to
      policy$max_tool_result_bytes <- optional(input$tools_result_kib) * 1024
      if (!length(policy$max_tool_result_bytes)) {
        policy$max_tool_result_bytes <- NULL
      }
      config$context_policy <- do.call(deputy::ContextPolicy, unclass(policy))
      config$working_dir <- input$tools_working_dir
      configure(config)
      shiny::updateSelectInput(
        session,
        "tool_choice",
        choices = inquiry_tool_choices(available_tools()),
        selected = "read_inquiry"
      )
      status("Tool access and execution limits updated for this session.")
      shiny::showNotification(
        "Tool access and execution limits updated.",
        type = "message"
      )
    })
  )
  output$tools_activity <- shiny::renderUI({
    agent <- current_agent()
    run <- activity()
    shiny::tagList(
      if (running()) {
        shiny::tagList(
          shiny::tags$p("A response is running."),
          shiny::actionButton(
            "tools_stop",
            "Stop response",
            class = "btn-outline-danger"
          )
        )
      },
      if (is.null(run)) {
        shiny::tags$p(
          "No execution receipt is available for this conversation yet."
        )
      } else {
        shiny::tagList(
          shiny::tags$h3(
            if (identical(run$source, "Saved interpretation")) {
              "Recorded interpretation run"
            } else {
              "Last recorded response"
            }
          ),
          shiny::tags$p(paste(run$model, "\u00b7", run$stop_reason)),
          shiny::tags$p(paste(
            run$usage$requests,
            "model requests \u00b7",
            run$usage$tool_calls,
            "tool calls \u00b7",
            run$usage$total_tokens,
            "tokens"
          )),
          shiny::tags$p(
            if (is.null(run$cost_usd)) {
              "Estimated cost unavailable."
            } else {
              sprintf("Estimated cost: $%.4f", run$cost_usd)
            }
          ),
          shiny::tags$ul(lapply(run$tools, function(tool) {
            shiny::tags$li(paste(tool$name, "\u2014", tool$status))
          })),
          shiny::tags$details(
            shiny::tags$summary("Execution receipt"),
            shiny::tags$pre(json_data(run, pretty = TRUE))
          )
        )
      },
      if (!is.null(agent)) {
        shiny::tags$p(
          class = "hint",
          paste(
            "Deputy permission mode:",
            agent$get_permission_mode(),
            "\u00b7",
            length(agent$skills()),
            "loaded skills \u00b7",
            length(agent$mcp_tools()),
            "MCP tools."
          )
        )
      }
    )
  })
  shiny::observeEvent(
    input$tools_stop,
    safely({
      agent <- current_agent()
      if (!is.null(agent) && running()) agent$interrupt("Stopped from Tools")
    })
  )
  shiny::observeEvent(input$tools_show_chat, shiny::removeModal())
  shiny::observeEvent(input$open_tools, open_tools())
  list(open = open_tools, selected = selected)
}
