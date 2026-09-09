#' Open the worked temperature example
#'
#' The manual workflow and local guidance need no credentials. Optionally supply
#' a factory that creates a fresh ellmer chat per session, for example
#' `function() ellmer::chat_openai(model = "your-model")`. The assistant gets
#' read-only access to the current formalization and can propose elicitation changes
#' for review. It cannot accept records or execute arbitrary R code.
#' @param record Optional record or bundle path. Defaults to the invented example.
#' @param chat_factory Optional function returning a fresh ellmer Chat.
#'   Use `suppose_muse` to connect Muse Spark Contributor through OpenRouter.
#' @return A Shiny app object; print it to run, or pass to `shiny::runApp()`.
#' @export
#' @examples
#' if (interactive()) suppose_example_app()
suppose_example_app <- function(record = NULL, chat_factory = NULL) {
  rlang::check_installed(c("shiny", "bslib", "shinychat"))
  if (!is.null(chat_factory) && !is.function(chat_factory)) {
    abort_suppose("{.arg chat_factory} must be a function or NULL.")
  }
  if (is.null(record)) {
    record <- suppose_example()
  }
  if (is.character(record)) {
    record <- read_record(record)
  }
  validate_record(record)
  ui <- bslib::page_fluid(
    title = "Suppose | Inspect a belief",
    theme = suppose_theme(),
    shiny::tags$head(shiny::tags$style(shiny::HTML(
      ".container-fluid {max-width:1440px;padding:28px 32px} h1{font-size:3rem}
       .eyebrow{text-transform:uppercase;letter-spacing:.14em;font-size:.75rem;color:#6c735e}
       .lead{max-width:780px} .card{border:1px solid #dfd3ec;box-shadow:none}
       .card-header{font-weight:600;background:transparent} .hint{color:#695775;font-size:.9rem}
       .metric{font:700 2.1rem var(--bs-font-sans-serif);margin:.3rem 0}.status{padding:12px;background:#eee5f8;border-radius:8px}
       textarea{min-height:72px}.btn{margin:3px 4px 3px 0} table{font-size:.85rem}
       :focus-visible{outline:3px solid #b74d08!important;outline-offset:3px}
       @media(max-width:600px){.container-fluid{padding:16px}h1{font-size:2.3rem}}"
    ))),
    shiny::tags$div(class = "eyebrow", "SUPPOSE / A WORKBENCH FOR INQUIRY"),
    shiny::tags$h1("What follows from your belief?"),
    shiny::tags$p(
      class = "lead",
      "Make the meaning precise. Inspect what your assumptions allow. Keep a record of what would change your mind."
    ),
    shiny::tags$p(
      class = "hint",
      "Local prototype \u00b7 Two-condition normal model \u00b7 Starting values are invented tutorial judgments"
    ),
    shiny::tags$div(
      role = "status",
      `aria-live` = "polite",
      shiny::textOutput("status"),
      class = "status"
    ),
    shiny::tags$br(),
    bslib::layout_columns(
      col_widths = c(4, 8),
      fill = FALSE,
      bslib::card(
        bslib::card_header("1 / Express the belief"),
        shiny::textInput("author", "Your name", "Demo scientist"),
        shiny::textAreaInput(
          "wording",
          "Claim in your own words",
          width = "100%"
        ),
        shiny::textAreaInput(
          "scope",
          "Population and protocol",
          width = "100%"
        ),
        shiny::numericInput("threshold", "Material improvement (MPa)", 5),
        shiny::tags$p(
          class = "hint",
          "Target: population mean strength at 160\u00b0C minus that at 140\u00b0C. A causal interpretation needs an appropriate intervention protocol."
        ),
        shiny::textInput(
          "reason",
          "Reason for this revision",
          "Review the implied improvement"
        ),
        shiny::actionButton("draft", "Retain claim draft"),
        shiny::tags$hr(),
        shiny::tags$strong("Uncertainty about the population means"),
        shiny::tags$p(
          class = "hint",
          "Enter the 5th and 95th percentiles: a central 90% probability interval for each mean, not a range of individual measurements."
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          fill = FALSE,
          shiny::numericInput(
            "low05",
            "140\u00b0C \u00b7 5th percentile (MPa)",
            45
          ),
          shiny::numericInput(
            "low95",
            "140\u00b0C \u00b7 95th percentile (MPa)",
            55
          ),
          shiny::numericInput(
            "high05",
            "160\u00b0C \u00b7 5th percentile (MPa)",
            51
          ),
          shiny::numericInput(
            "high95",
            "160\u00b0C \u00b7 95th percentile (MPa)",
            65
          )
        ),
        shiny::numericInput(
          "rho",
          "Correlation of uncertain means",
          .8,
          min = -1,
          max = 1,
          step = .1
        ),
        shiny::tags$p(
          class = "hint",
          "Positive correlation says both means tend to shift together. The intervals above cannot identify this assumption."
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          fill = FALSE,
          shiny::numericInput(
            "sd_low",
            "Batch SD at 140\u00b0C (MPa)",
            3,
            min = 0
          ),
          shiny::numericInput(
            "sd_high",
            "Batch SD at 160\u00b0C (MPa)",
            3,
            min = 0
          )
        ),
        shiny::textAreaInput(
          "basis",
          "Judgment rationale and information already seen",
          "Invented tutorial values; no observations used.",
          width = "100%"
        ),
        shiny::numericInput("seed", "Simulation seed", 47, min = 0, step = 1),
        shiny::actionButton(
          "inspect",
          "Inspect these expectations",
          class = "btn-primary"
        )
      ),
      shiny::tagList(
        bslib::card(
          bslib::card_header("2 / Inspect the consequences"),
          shiny::uiOutput("meaning"),
          bslib::layout_columns(
            col_widths = c(6, 6),
            fill = FALSE,
            shiny::uiOutput("mean_metric"),
            shiny::uiOutput("prob_metric")
          ),
          shiny::plotOutput("prediction_plot", height = "300px"),
          shiny::textOutput("plot_description"),
          shiny::tags$div(
            class = "table-responsive",
            tabindex = "0",
            role = "region",
            `aria-label` = "Predictive summary in MPa; scroll horizontally for all columns",
            shiny::tableOutput("summary")
          ),
          shiny::tags$details(
            shiny::tags$summary("Fitting diagnostics and model limits"),
            shiny::textOutput("diagnostics"),
            shiny::tags$div(
              class = "table-responsive",
              tabindex = "0",
              role = "region",
              `aria-label` = "Elicited and implied quantiles; scroll horizontally for all columns",
              shiny::tableOutput("fit_table")
            )
          ),
          shiny::tags$p(
            class = "hint",
            "These are consequences of the stated model and judgments. They are not measurements or empirical evidence for the claim."
          )
        ),
        bslib::card(
          bslib::card_header("3 / Review and retain"),
          shiny::textAreaInput(
            "accept_reason",
            "Why does this formalization express your belief?",
            width = "100%"
          ),
          shiny::textAreaInput(
            "challenge",
            "What evidence or check would challenge it?",
            width = "100%"
          ),
          shiny::checkboxInput(
            "reviewed",
            "I reviewed the meaning, assumptions, and implied outcomes",
            FALSE
          ),
          shiny::actionButton(
            "accept",
            "Accept reviewed revision",
            class = "btn-primary"
          ),
          shiny::tags$div(
            class = "table-responsive",
            tabindex = "0",
            role = "region",
            `aria-label` = "Revision history; scroll horizontally for all columns",
            shiny::tableOutput("history")
          ),
          shiny::selectInput(
            "history_revision",
            "Inspect a retained revision",
            choices = character()
          ),
          shiny::uiOutput("accepted_details"),
          shiny::downloadButton("download", "Save record (.json)"),
          shiny::fileInput("upload", "Reopen a saved record", accept = ".json")
        ),
        bslib::card(
          bslib::card_header("Talk through the meaning"),
          shiny::tags$p(
            class = "hint",
            if (is.null(chat_factory)) {
              "Local guide: ask about correlation, intervals, or a challenge. No AI service is connected."
            } else {
              "Assistant suggestions require your review. Numerical results come from the model APIs."
            }
          ),
          shiny::textOutput("guide_status"),
          shinychat::chat_ui(
            "guide",
            width = "100%",
            height = "330px",
            fill = FALSE,
            show_history = FALSE,
            allow_attachments = FALSE,
            greeting = "Which assumption would you like to inspect?"
          ),
          shiny::verbatimTextOutput("proposal"),
          shiny::verbatimTextOutput("assistance"),
          shiny::actionButton(
            "apply_proposal",
            "Apply proposal as a reviewable revision"
          ),
          shiny::actionButton("decline_proposal", "Decline suggestion")
        )
      )
    )
  )
  shiny::shinyApp(ui, function(input, output, session) {
    workbench_server(input, output, session, record, chat_factory)
  })
}

workbench_server <- function(
  input,
  output,
  session,
  initial,
  chat_factory = NULL
) {
  current <- shiny::reactiveVal(initial)
  status <- shiny::reactiveVal(
    "Explore the illustrative candidate, or edit the inputs and inspect a new revision."
  )
  proposal <- shiny::reactiveVal(NULL)
  assistant <- NULL
  chat <- NULL
  proposal_form <- NULL
  reviewed_inputs <- shiny::reactiveVal(NULL)
  latest <- shiny::reactive(utils::tail(current()$revisions, 1)[[1]])
  form <- shiny::reactive(lapply(
    c(
      "wording",
      "scope",
      "author",
      "threshold",
      "reason",
      "low05",
      "low95",
      "high05",
      "high95",
      "rho",
      "sd_low",
      "sd_high",
      "basis",
      "seed"
    ),
    function(nm) input[[nm]]
  ))
  visible <- shiny::reactive({
    i <- suppressWarnings(as.integer(input$history_revision))
    if (
      length(i) != 1 || is.na(i) || i < 1 || i > length(current()$revisions)
    ) {
      return(latest())
    }
    current()$revisions[[i]]
  })
  sync_form <- function(entry) {
    c <- entry$claim
    shiny::updateTextInput(session, "author", value = c$author)
    shiny::updateTextAreaInput(session, "wording", value = c$wording)
    shiny::updateTextAreaInput(session, "scope", value = c$scope %||% "")
    shiny::updateNumericInput(session, "threshold", value = c$threshold %||% 5)
    if (!is.null(entry$candidate)) {
      p <- entry$candidate
      for (i in seq_along(p$judgments)) {
        j <- p$judgments[[i]]
        vals <- stats::qnorm(c(.05, .95), p$means[i], p$mean_sd[i])
        prefix <- if (i == 1) "low" else "high"
        shiny::updateNumericInput(
          session,
          paste0(prefix, "05"),
          value = vals[1]
        )
        shiny::updateNumericInput(
          session,
          paste0(prefix, "95"),
          value = vals[2]
        )
      }
      shiny::updateSliderInput(session, "rho", value = p$correlation)
      shiny::updateNumericInput(session, "sd_low", value = p$batch_sd[1])
      shiny::updateNumericInput(session, "sd_high", value = p$batch_sd[2])
      shiny::updateTextAreaInput(
        session,
        "basis",
        value = p$judgments[[1]]$rationale %||%
          p$judgments[[1]]$source %||%
          "Unknown information basis"
      )
    }
    if (is.null(entry$candidate)) {
      for (nm in c("low05", "low95", "high05", "high95", "sd_low", "sd_high")) {
        shiny::updateNumericInput(session, nm, value = NA_real_)
      }
    }
    if (!is.null(entry$prediction)) {
      shiny::updateNumericInput(session, "seed", value = entry$prediction$seed)
    }
    reviewed_inputs(NULL)
    shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
  }
  shiny::observeEvent(
    TRUE,
    {
      sync_form(latest())
    },
    once = TRUE
  )
  safely <- function(code) {
    tryCatch(force(code), error = function(e) {
      status(cli::ansi_strip(conditionMessage(e)))
      shiny::showNotification(
        cli::ansi_strip(conditionMessage(e)),
        type = "error",
        duration = 8
      )
      invisible(NULL)
    })
  }
  make_claim <- function() {
    old <- latest()$claim
    fields <- list(
      wording = input$wording,
      scope = input$scope,
      threshold = input$threshold
    )
    if (
      identical(old$wording, fields$wording) &&
        identical(old$scope, fields$scope) &&
        identical(old$threshold, fields$threshold) &&
        identical(old$author, input$author)
    ) {
      return(old)
    }
    do.call(
      revise_claim,
      c(list(old, author = input$author, reason = input$reason), fields)
    )
  }
  shiny::observeEvent(
    input$draft,
    safely({
      out <- record_revision(current(), make_claim(), reason = input$reason)
      current(out)
      reviewed_inputs(NULL)
      status(
        "Claim draft retained. No numerical formalization has been accepted."
      )
    })
  )
  shiny::observeEvent(
    input$inspect,
    safely({
      c <- make_claim()
      check_text(input$basis, "Judgment rationale and information already seen")
      js <- list(
        judgment(
          140,
          c(input$low05, input$low95),
          c(.05, .95),
          units = "MPa",
          author = input$author,
          answer = sprintf(
            "5th and 95th percentiles of the mean: %s, %s MPa",
            input$low05,
            input$low95
          ),
          rationale = input$basis,
          observed = input$basis
        ),
        judgment(
          160,
          c(input$high05, input$high95),
          c(.05, .95),
          units = "MPa",
          author = input$author,
          answer = sprintf(
            "5th and 95th percentiles of the mean: %s, %s MPa",
            input$high05,
            input$high95
          ),
          rationale = input$basis,
          observed = input$basis
        )
      )
      p <- fit_prior(
        c,
        js,
        correlation = input$rho,
        batch_sd = c(input$sd_low, input$sd_high)
      )
      pred <- predict_prior(p, seed = input$seed)
      current(record_revision(
        current(),
        c,
        p,
        pred,
        reason = input$reason,
        assistance = latest()$assistance
      ))
      reviewed_inputs(form())
      shiny::updateCheckboxInput(session, "reviewed", value = FALSE)
      status(
        "New candidate retained. Review its implications before acceptance."
      )
    })
  )
  shiny::observeEvent(
    input$accept,
    safely({
      if (!isTRUE(input$reviewed)) {
        abort_suppose(
          "Confirm that you reviewed the meaning and predictions.",
          "review"
        )
      }
      if (is.null(reviewed_inputs()) || !identical(reviewed_inputs(), form())) {
        abort_suppose(
          "Inspect the current inputs before accepting; the displayed candidate may be from earlier inputs.",
          "stale"
        )
      }
      if (!identical(visible()$prediction$id, latest()$prediction$id)) {
        abort_suppose(
          "Select the latest revision before accepting it.",
          "stale"
        )
      }
      current(accept_revision(
        current(),
        input$author,
        input$accept_reason,
        input$challenge
      ))
      status("Reviewed revision accepted. Save the record to reopen it later.")
    })
  )
  shiny::observe({
    n <- length(current()$revisions)
    shiny::updateSelectInput(
      session,
      "history_revision",
      choices = stats::setNames(seq_len(n), paste("Revision", seq_len(n))),
      selected = n
    )
  })
  shiny::observeEvent(
    input$upload,
    safely({
      out <- read_record(input$upload$datapath)
      # This UI deliberately supports the bounded temperature example only.
      e <- utils::tail(out$revisions, 1)[[1]]
      if (
        !identical(e$claim$units, "MPa") ||
          (!is.null(e$candidate) &&
            (!identical(as.numeric(e$candidate$conditions), c(140, 160)) ||
              e$candidate$condition_units != "degC"))
      ) {
        abort_suppose(
          "This workbench edits the 140/160 degC MPa example. Inspect other bundles with the R APIs.",
          "unsupported"
        )
      }
      if (!is.null(assistant)) {
        if (assistant$phase == "running") {
          abort_suppose(
            "Finish or cancel the assistant response before reopening a record.",
            "busy"
          )
        }
        assistant$reset()
        chat$clear()
      }
      current(out)
      sync_form(e)
      status(
        "Saved record reopened without recomputing. Inspect inputs to begin a new review."
      )
    })
  )
  output$status <- shiny::renderText(status())
  output$meaning <- shiny::renderUI({
    c <- visible()$claim
    shiny::tagList(
      shiny::tags$p(shiny::tags$em(c$original_wording)),
      shiny::tags$p(shiny::tags$strong("Current claim: "), c$wording),
      shiny::tags$p(shiny::tags$strong("Target: "), c$target %||% "Unresolved")
    )
  })
  output$mean_metric <- shiny::renderUI({
    p <- visible()$prediction
    if (is.null(p)) {
      return(shiny::tags$p("Inspect expectations to compute predictions."))
    }
    shiny::tagList(
      shiny::tags$div(class = "hint", "Expected mean improvement"),
      shiny::tags$div(
        class = "metric",
        sprintf("%.1f MPa", p$summary$mean_difference$mean)
      )
    )
  })
  output$prob_metric <- shiny::renderUI({
    p <- visible()$prediction
    if (is.null(p)) {
      return(NULL)
    }
    shiny::tagList(
      shiny::tags$div(
        class = "hint",
        sprintf("Prior probability of exceeding %g MPa", p$threshold)
      ),
      shiny::tags$div(
        class = "metric",
        sprintf("%.1f%%", 100 * p$summary$mean_difference$probability_above)
      )
    )
  })
  output$prediction_plot <- shiny::renderPlot(
    {
      p <- visible()$prediction
      shiny::req(p)
      plot.suppose_prediction(p)
    },
    alt = "Simulated mean and future-batch differences, with a material threshold. Exact intervals appear in the adjacent text and table."
  )
  output$plot_description <- shiny::renderText({
    p <- visible()$prediction
    if (is.null(p)) {
      return("")
    }
    s <- p$summary
    sprintf(
      "Central 90%% prior interval: %.2f to %.2f MPa for the mean difference; %.2f to %.2f MPa for two future batches.",
      s$mean_difference$lower,
      s$mean_difference$upper,
      s$batch_difference$lower,
      s$batch_difference$upper
    )
  })
  output$summary <- shiny::renderTable(
    {
      p <- visible()$prediction
      shiny::req(p)
      data.frame(
        Quantity = c(
          "Population mean difference",
          "Two future batch measurements"
        ),
        Mean = vapply(p$summary, `[[`, numeric(1), "mean"),
        SD = vapply(p$summary, `[[`, numeric(1), "sd"),
        `5th percentile` = vapply(p$summary, `[[`, numeric(1), "lower"),
        `95th percentile` = vapply(p$summary, `[[`, numeric(1), "upper"),
        check.names = FALSE
      )
    },
    digits = 2,
    rownames = FALSE
  )
  output$diagnostics <- shiny::renderText({
    p <- visible()$candidate
    if (is.null(p)) {
      return("No candidate in this revision.")
    }
    paste(
      sprintf(
        "Maximum quantile mismatch: %.4g MPa. Correlation: %.2f. Maximum negative future-batch probability: %.4g.",
        p$max_error,
        p$correlation,
        max(p$negative_batch_probability)
      ),
      paste(p$assumptions, collapse = " ")
    )
  })
  output$fit_table <- shiny::renderTable(
    {
      p <- visible()$candidate
      shiny::req(p)
      do.call(
        rbind,
        lapply(seq_along(p$judgments), function(i) {
          j <- p$judgments[[i]]
          data.frame(
            Temperature = j$condition,
            Probability = j$probabilities,
            Elicited = j$values,
            Implied = p$fits[[i]]$implied
          )
        })
      )
    },
    digits = 3
  )
  output$history <- shiny::renderTable(
    {
      entries <- current()$revisions
      data.frame(
        Revision = seq_along(entries),
        Status = vapply(
          entries,
          function(e) {
            if (!is.null(e$acceptance)) {
              "Accepted"
            } else if (!is.null(e$candidate)) {
              "Proposed"
            } else {
              "Draft"
            }
          },
          character(1)
        ),
        Correlation = vapply(
          entries,
          function(e) e$candidate$correlation %||% NA_real_,
          numeric(1)
        ),
        `P(above threshold)` = vapply(
          entries,
          function(e) {
            e$prediction$summary$mean_difference$probability_above %||% NA_real_
          },
          numeric(1)
        ),
        Reason = vapply(entries, `[[`, character(1), "reason"),
        check.names = FALSE
      )
    },
    digits = 3
  )
  output$accepted_details <- shiny::renderUI({
    a <- visible()$acceptance
    if (is.null(a)) {
      return(shiny::tags$p(
        class = "hint",
        "This revision has not been accepted."
      ))
    }
    shiny::tags$div(
      shiny::tags$p(shiny::tags$strong("Accepted by: "), a$author),
      shiny::tags$p(shiny::tags$strong("Review rationale: "), a$reason),
      shiny::tags$p(shiny::tags$strong("Concrete challenge: "), a$challenge)
    )
  })
  output$download <- shiny::downloadHandler(
    filename = function() "suppose-record.json",
    content = function(file) write_record(current(), file, overwrite = TRUE),
    contentType = "application/json"
  )
  output$proposal <- shiny::renderText({
    p <- proposal()
    if (is.null(p)) {
      return("")
    }
    old <- latest()
    paste(
      "PROPOSED: review before applying",
      "Current claim:",
      old$claim$wording,
      "Proposed claim:",
      p$claim$wording,
      "Proposed scope:",
      p$claim$scope,
      "Proposed target:",
      p$claim$target,
      "Threshold:",
      p$claim$threshold,
      "Judgments (exact source answers):",
      paste(
        vapply(
          p$judgments,
          function(j) paste(j$condition, j$kind, j$quantity, j$answer),
          character(1)
        ),
        collapse = "\n"
      ),
      "Current correlation / batch SDs:",
      old$candidate$correlation,
      paste(old$candidate$batch_sd, collapse = ", "),
      "Proposed assumptions:",
      paste(
        "Correlation:",
        p$candidate$correlation %||%
          p$changes$assumptions$correlation %||%
          "unresolved",
        "; batch SDs (MPa):",
        paste(
          p$candidate$batch_sd %||%
            p$changes$assumptions$batch_sd %||%
            "unresolved",
          collapse = ", "
        )
      ),
      "Preview:",
      if (is.null(p$preview_issue)) {
        summary <- p$prediction$summary
        sprintf(
          "Mean improvement %.2f MPa; central 90%% interval %.2f to %.2f MPa.\nPrior probability above the threshold: %.1f%%.\nTwo future batches: central 90%% interval %.2f to %.2f MPa.",
          summary$mean_difference$mean,
          summary$mean_difference$lower,
          summary$mean_difference$upper,
          100 * summary$mean_difference$probability_above,
          summary$batch_difference$lower,
          summary$batch_difference$upper
        )
      } else {
        p$preview_issue
      },
      "Reason:",
      p$reason,
      "No acceptance has occurred.",
      sep = "\n"
    )
  })
  output$assistance <- shiny::renderText({
    a <- visible()$assistance
    if (is.null(a)) {
      return("")
    }
    paste(
      "Retained assistant provenance",
      a$proposal$context$model,
      paste("Applied by", a$applied_by, "at", a$applied_at),
      paste(
        vapply(
          a$proposal$context$messages,
          function(m) paste(m$role, m$text, sep = ": "),
          character(1)
        ),
        collapse = "\n\n"
      ),
      paste("Proposal", a$proposal$id),
      sep = "\n"
    )
  })
  shiny::observeEvent(
    input$apply_proposal,
    safely({
      p <- proposal()
      if (is.null(p)) {
        abort_suppose("No completed proposal is awaiting review.", "proposal")
      }
      if (!identical(proposal_form, form())) {
        abort_suppose(
          "The form changed during this conversation. Retain or inspect those edits, then request a new proposal.",
          "stale"
        )
      }
      out <- apply_assistant_proposal(current(), p, input$author)
      current(out)
      sync_form(utils::tail(out$revisions, 1)[[1]])
      shiny::updateTextInput(session, "reason", value = p$reason)
      assistant$clear_proposal()
      status(
        "Proposal retained with conversation and model provenance. Inspect the form and predictions before accepting."
      )
    })
  )
  shiny::observeEvent(input$decline_proposal, {
    if (!is.null(assistant)) {
      assistant$clear_proposal()
    }
    proposal(NULL)
  })
  client <- if (!is.null(chat_factory)) safely(chat_factory()) else NULL
  if (!is.null(client)) {
    rlang::check_installed("ellmer")
    output$guide_status <- shiny::renderText({
      model <- client$get_model()
      paste(
        "Connected model:",
        model,
        if (grepl("contributor", model, fixed = TRUE)) {
          "Contributor permits use of prompts and outputs to improve Meta products."
        } else {
          ""
        },
        "Conversation and retained context are sent to the provider; applied proposals retain the conversation in saved records."
      )
    })
    client$set_system_prompt(assistant_prompt())
    assistant <- new_proposal_session(
      function() shiny::isolate(current()),
      function(p) proposal(p),
      model = client$get_model(),
      provider = "ellmer"
    )
    shiny::observeEvent(
      input$guide_user_input,
      safely({
        proposal_form <<- form()
        text <- input$guide_user_input
        if (is.list(text)) {
          text <- paste(
            vapply(
              text,
              function(x) {
                if (is.character(x)) x else ellmer::contents_text(x)
              },
              character(1)
            ),
            collapse = "\n"
          )
        }
        id <- assistant$begin(text)
        client$set_tools(assistant$tools(id))
      }),
      priority = 100
    )
    chat <- shinychat::chat_server("guide", client, history = FALSE)
    shiny::observeEvent(
      chat$last_turn(),
      safely({
        if (assistant$phase == "running") {
          tryCatch(
            assistant$finish(
              assistant$request$id,
              ellmer::contents_text(chat$last_turn())
            ),
            error = function(e) {
              assistant$cancel("failed")
              stop(e)
            }
          )
        }
      })
    )
    shiny::observeEvent(chat$last_error(), {
      assistant$cancel("failed")
      status(
        "Assistant response failed. No incomplete proposal was applied; send your message again to retry."
      )
    })
    shiny::observeEvent(
      input$guide_cancel,
      {
        assistant$cancel()
      },
      priority = 100
    )
  } else {
    output$guide_status <- shiny::renderText(
      "Local guide active. No inference requests are sent."
    )
    shiny::observeEvent(input$guide_user_input, {
      shinychat::chat_append(
        "guide",
        local_guidance(input$guide_user_input, latest())
      )
    })
  }
  invisible(list(record = current, status = status, proposal = proposal))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

local_guidance <- function(text, entry) {
  text <- tolower(paste(text, collapse = " "))
  if (grepl("correl|assumption|together", text)) {
    return(paste(
      "The two marginal intervals do not determine how the uncertain means move together.",
      "Try correlation 0 and then 0.8, keeping the intervals fixed. Inspect each candidate",
      "and compare the mean-difference interval in the history. This checks a modeling assumption, not the material."
    ))
  }
  if (grepl("range|interval|mean|variation", text)) {
    return(paste(
      "These inputs are the 5th and 95th percentiles of uncertainty about a population mean.",
      "Individual batches can vary even if the mean is known. Batch SD supplies that separate variation.",
      "If your answer is only a plausible range, retain a claim draft and clarify its probability meaning before fitting."
    ))
  }
  if (grepl("challenge|test|caus|evidence", text)) {
    return(paste(
      "A concrete challenge is to compare independently prepared batches under a justified randomized",
      "temperature protocol, holding formulation and cure duration fixed. Define the sampling and",
      "assessment rule before inspecting outcomes. Two temperature predictions alone do not establish causality or monotonicity."
    ))
  }
  "This local guide has fixed explanations for correlation, mean intervals, and evidence challenges. Ask about one of those, or edit the form to explore your own expectations."
}
