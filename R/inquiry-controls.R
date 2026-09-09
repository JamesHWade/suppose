# The catalog contains metadata only. Credentials stay in the HTTP request.
inquiry_model_catalog <- function(models) {
  valid <- Filter(
    function(m) {
      is.character(m$id) &&
        length(m$id) == 1L &&
        !grepl(":batch$", m$id) &&
        "tools" %in% unlist(m$supported_parameters) &&
        "text" %in% unlist(m$architecture$input_modalities) &&
        "text" %in% unlist(m$architecture$output_modalities)
    },
    models
  )
  price <- function(x) {
    x <- suppressWarnings(as.numeric(x %||% NA_character_))
    if (length(x) != 1L || !is.finite(x) || x < 0) NA_real_ else x * 1e6
  }
  out <- lapply(valid, function(m) {
    list(
      id = m$id,
      name = m$name %||% m$id,
      provider = sub("/.*", "", m$id),
      description = m$description %||% "",
      context = m$context_length,
      input_price = price(m$pricing$prompt),
      output_price = price(m$pricing$completion),
      tiered = length(m$pricing$overrides) > 0,
      max_output = m$top_provider$max_completion_tokens,
      parameters = unlist(m$supported_parameters)
    )
  })
  stats::setNames(out, vapply(out, `[[`, character(1), "id"))
}

inquiry_catalog_request <- function() {
  rlang::check_installed("httr2")
  key <- Sys.getenv("OPENROUTER_API_KEY")
  if (!nzchar(key)) {
    abort_suppose(
      "Configure OPENROUTER_API_KEY locally to browse OpenRouter models.",
      "credentials"
    )
  }
  httr2::request("https://openrouter.ai/api/v1/models/user") |>
    httr2::req_auth_bearer_token(key) |>
    httr2::req_timeout(15)
}

inquiry_controls <- function(
  input,
  output,
  session,
  current_agent,
  switch_agent,
  busy,
  status,
  catalog_request = inquiry_catalog_request,
  open_tools = function() NULL,
  open_test = function() NULL,
  open_sensitivity = function() NULL,
  open_extension = function() NULL,
  open_design = function() NULL,
  open_regression = function() NULL
) {
  opened <- shiny::reactiveVal(0L)
  catalog <- shiny::reactiveVal(list())
  catalog_state <- shiny::reactiveVal(
    "Open the picker to load available models."
  )
  catalog_task <- shiny::ExtendedTask$new(function() {
    req <- catalog_request()
    promises::then(httr2::req_perform_promise(req), function(resp) {
      inquiry_model_catalog(httr2::resp_body_json(resp)$data)
    })
  })
  shiny::observe({
    task_status <- catalog_task$status()
    if (task_status == "running") {
      catalog_state("Loading models from OpenRouter...")
    } else if (task_status == "success") {
      catalog(catalog_task$result())
      catalog_state(paste(
        length(catalog()),
        "models available. Listed prices are base rates."
      ))
    } else if (task_status == "error") {
      # Do not expose credential-bearing request objects in the UI.
      catalog_state(
        "Could not load the catalog. Check your OpenRouter key and connection, then refresh. The current model is unchanged."
      )
    }
  })
  open_models <- function() {
    agent <- current_agent()
    shiny::showModal(shiny::modalDialog(
      title = "Choose a conversation model",
      size = "l",
      easyClose = TRUE,
      shiny::tags$p(
        class = "hint",
        if (is.null(agent)) {
          "Current: local guide"
        } else {
          paste("Current:", agent$get_model())
        }
      ),
      shiny::selectizeInput(
        "model_choice",
        "Search models",
        width = "100%",
        choices = character(),
        options = list(
          placeholder = "Search by model name or ID...",
          maxOptions = 500
        )
      ),
      shiny::uiOutput("model_details"),
      shiny::tags$details(
        shiny::tags$summary("Advanced options"),
        bslib::layout_columns(
          shiny::selectInput(
            "model_provider",
            "Provider",
            choices = c("All providers" = "")
          ),
          shiny::selectInput(
            "model_price",
            "Price",
            choices = c(
              "All prices" = "all",
              "Free token rates" = "free",
              "Up to $1 / M input tokens" = "low"
            )
          ),
          col_widths = c(6, 6),
          fill = FALSE
        ),
        shiny::numericInput(
          "model_max_tokens",
          "Maximum output tokens per request (including reasoning)",
          4096,
          min = 256,
          max = 65536,
          step = 256
        ),
        shiny::uiOutput("model_technical_details"),
        shiny::actionButton("refresh_models", "Refresh models")
      ),
      shiny::tags$p(
        class = "hint",
        "Switching keeps this conversation and record. Future messages and retained context go to the selected provider under your OpenRouter privacy settings."
      ),
      shiny::tags$div(
        role = "status",
        `aria-live` = "polite",
        shiny::textOutput("model_catalog_status")
      ),
      footer = shiny::tagList(
        shiny::modalButton("Cancel"),
        shiny::actionButton("choose_model", "Use model", class = "btn-primary")
      )
    ))
    opened(shiny::isolate(opened()) + 1L)
    if (
      !length(shiny::isolate(catalog())) &&
        shiny::isolate(catalog_task$status()) != "running"
    ) {
      catalog_task$invoke()
    }
  }
  output$model_catalog_status <- shiny::renderText(catalog_state())
  shiny::observeEvent(input$refresh_models, {
    if (catalog_task$status() != "running") catalog_task$invoke()
  })
  shiny::observe({
    opened()
    x <- catalog()
    providers <- sort(unique(vapply(x, `[[`, character(1), "provider")))
    shiny::updateSelectInput(
      session,
      "model_provider",
      choices = c("All providers" = "", stats::setNames(providers, providers)),
      selected = shiny::isolate(input$model_provider) %||% ""
    )
  })
  filtered <- shiny::reactive({
    Filter(
      function(m) {
        provider <- input$model_provider %||% ""
        price <- input$model_price %||% "all"
        (!nzchar(provider) || identical(provider, m$provider)) &&
          (price == "all" ||
            (price == "free" &&
              !is.na(m$input_price) &&
              !is.na(m$output_price) &&
              m$input_price == 0 &&
              m$output_price == 0) ||
            (price == "low" && !is.na(m$input_price) && m$input_price <= 1))
      },
      catalog()
    )
  })
  shiny::observe({
    opened()
    x <- filtered()
    labels <- vapply(x, function(m) paste(m$name, "-", m$id), character(1))
    choices <- stats::setNames(names(x) %||% character(), labels)
    previous <- shiny::isolate(input$model_choice)
    active <- current_agent()
    preferred <- if (!is.null(active)) {
      active$get_model()
    } else {
      "meta/muse-spark-1.3-contributor"
    }
    selected <- if (length(previous) && previous %in% names(x)) {
      previous
    } else if (preferred %in% names(x)) {
      preferred
    } else {
      ""
    }
    shiny::updateSelectizeInput(
      session,
      "model_choice",
      choices = choices,
      selected = selected,
      server = TRUE
    )
  })
  output$model_details <- shiny::renderUI({
    m <- catalog()[[input$model_choice %||% ""]]
    if (is.null(m)) {
      return(shiny::tags$p(
        class = "hint",
        "Select a model to see its details."
      ))
    }
    dollars <- function(x) {
      if (is.na(x)) {
        "Not supplied"
      } else {
        paste0("$", format(x, trim = TRUE, scientific = FALSE))
      }
    }
    shiny::tagList(
      shiny::tags$p(
        class = "hint",
        paste0(
          dollars(m$input_price),
          " input / ",
          dollars(m$output_price),
          " output per million tokens",
          if (m$tiered) " (base tier)" else ""
        )
      ),
      if (grepl("contributor", m$id, fixed = TRUE)) {
        shiny::tags$p(
          class = "hint",
          "Contributor permits training use of prompts and outputs."
        )
      }
    )
  })
  output$model_technical_details <- shiny::renderUI({
    m <- catalog()[[input$model_choice %||% ""]]
    if (is.null(m)) {
      return(NULL)
    }
    shiny::tagList(
      inquiry_field(
        "Context window",
        if (is.null(m$context)) {
          "Not supplied"
        } else {
          paste(format(m$context, big.mark = ",", scientific = FALSE), "tokens")
        }
      ),
      shiny::tags$p(
        class = "hint",
        "Models support text and tool calls. Routing, long-context pricing tiers, provider capacity, and account credit can affect availability and cost."
      ),
      shiny::tags$a(
        href = paste0("https://openrouter.ai/", m$id),
        target = "_blank",
        rel = "noopener noreferrer",
        "Full model details on OpenRouter"
      )
    )
  })
  shiny::observeEvent(input$choose_model, {
    tryCatch(
      {
        busy()
        m <- catalog()[[input$model_choice %||% ""]]
        if (is.null(m)) {
          abort_suppose("Select a model from the available catalog.", "model")
        }
        limit <- input$model_max_tokens
        check_count(limit, "maximum output tokens", 256, 65536)
        if (!is.null(m$max_output) && limit > m$max_output) {
          abort_suppose(
            paste(
              "This model supports at most",
              m$max_output,
              "output tokens per request."
            ),
            "model"
          )
        }
        new_agent <- do.call(
          suppose_agent,
          c(
            list(
              chat = suppose_muse(
                model = m$id,
                max_tokens = limit
              )
            ),
            inquiry_agent_config(current_agent()) %||% list()
          )
        )
        switch_agent(new_agent)
        shiny::removeModal()
        status(paste("Now using", m$name, "for the next message."))
      },
      error = function(e) {
        shiny::showNotification(
          cli::ansi_strip(conditionMessage(e)),
          type = "error"
        )
      }
    )
  })
  open_record <- function() shinychat::chat_drawer_show("inquiry")
  help <- function() {
    descriptions <- c(
      record = "Open your developing record",
      test = "Plan or assess a future test",
      sensitivity = "Review prior and likelihood sensitivity",
      extend = "Review an added predictor",
      design = "Plan the next measurement with Bayesian design",
      regression = "Fit, check and compare regression models",
      model = "Choose the conversation model",
      tools = "Use tools and configure Deputy",
      help = "Show commands"
    )
    shiny::showModal(shiny::modalDialog(
      title = "Inquiry commands",
      easyClose = TRUE,
      shiny::tags$p(
        if (is.null(current_agent())) {
          "Choose a model to enable / commands in the composer. You can also use the buttons below."
        } else {
          "Type / in the chat to open the record, choose a model, or find help."
        }
      ),
      shiny::tags$div(
        class = "command-list",
        lapply(names(descriptions), function(nm) {
          shiny::actionButton(
            paste0("command_", nm),
            shiny::tagList(
              shiny::tags$strong(paste0("/", nm)),
              shiny::tags$span(descriptions[[nm]])
            )
          )
        })
      ),
      footer = shiny::modalButton("Close")
    ))
  }
  handlers <- list(
    record = open_record,
    test = open_test,
    sensitivity = open_sensitivity,
    extend = open_extension,
    design = open_design,
    regression = open_regression,
    model = open_models,
    tools = open_tools,
    help = help
  )
  for (nm in names(handlers)) {
    local({
      name <- nm
      shiny::observeEvent(input[[paste0("command_", name)]], {
        shiny::removeModal()
        handlers[[name]]()
      })
    })
  }
  shiny::observeEvent(input$open_models, open_models())
  shiny::observeEvent(input$open_commands, help())
  register <- function(chat) {
    descriptions <- c(
      record = "Open the developing record",
      test = "Plan or assess a future test",
      sensitivity = "Review prior and likelihood sensitivity",
      extend = "Review an added predictor",
      design = "Plan the next measurement with Bayesian design",
      regression = "Fit, check and compare regression models",
      model = "Choose a model",
      tools = "Use tools and configure Deputy",
      help = "Show all commands"
    )
    for (nm in names(handlers)) {
      chat$slash_command(nm, descriptions[[nm]], handlers[[nm]], echo = FALSE)
    }
  }
  list(
    register = register,
    catalog = catalog,
    handlers = handlers
  )
}
