world_inventory <- function(x) {
  validate_model_world(x)
  list(
    id = x$id,
    title = x$title,
    scope = x$scope,
    source = x$source,
    threshold = x$threshold,
    lower_bound = x$lower_bound,
    varying = x$varying,
    units = x$units,
    outcome_units = x$outcome_units,
    training_range = x$training_range,
    structure = x$structure,
    assumptions = x$assumptions,
    capabilities = x$capabilities,
    limitations = x$limitations,
    provenance = x$provenance,
    summary_definition = list(
      quantiles = c(0.05, 0.5, 0.95),
      central_probability = 0.9,
      interval_scope = 'Pointwise at the stated scenario; not simultaneous curve coverage.',
      expected = 'Uncertainty about the average outcome.',
      future = 'Uncertainty about one individual future outcome, including outcome variation.',
      probabilities = 'Fractions of the retained posterior draws; Monte Carlo estimates, not exact probabilities.'
    ),
    scenario_summaries = lapply(seq_along(x$scenarios), function(i) {
      c(
        list(settings = x$scenarios[[i]]),
        world_summary(x, i, validated = TRUE)
      )
    })
  )
}

model_world_ui <- function(id, worlds, values = list()) {
  ns <- shiny::NS(id)
  selected <- values$model
  if (is.null(selected) || !selected %in% names(worlds)) {
    selected <- names(worlds)[1]
  }
  w <- worlds[[selected]]
  settings <- vapply(w$scenarios, function(s) s[[w$varying]], numeric(1))
  center <- settings[which.min(abs(settings - mean(w$training_range)))]
  compatible <- Filter(
    function(other) world_comparable(w, other) && w$id != other$id,
    worlds
  )
  comparisons <- c(
    'No comparison' = 'none',
    stats::setNames(
      names(compatible),
      vapply(compatible, function(z) z$title, character(1))
    )
  )

  shiny::tagList(
    suppose_dependency(
      "model-world",
      stylesheet = "model-world.css",
      script = "world-range.js"
    ),
    shiny::tags$script(shiny::HTML(paste0(
      "setTimeout(function(){Shiny.setInputValue(\"",
      ns("mounted"),
      "\",Date.now(),{priority:\"event\"});},150);"
    ))),
    shiny::tags$div(
      class = 'model-world',
      shiny::p(
        'Start with a model. Explore the outcomes it allows, then decide which implications match your understanding. These saved simulations open without a model provider.'
      ),
      shiny::selectInput(
        ns('model'),
        'Choose a starting model',
        stats::setNames(
          names(worlds),
          vapply(worlds, function(z) z$title, character(1))
        ),
        selected = selected,
        selectize = FALSE
      ),
      shiny::uiOutput(ns('intro')),
      shiny::tags$p(
        class = 'world-step',
        '1 \u00b7 Read the model\u2019s commitments'
      ),
      shiny::uiOutput(ns('structure')),
      shiny::tags$p(class = 'world-step', '2 \u00b7 Explore possible outcomes'),
      shiny::tags$div(
        class = 'world-explorer',
        shiny::tags$div(
          class = 'world-control-pane',
          shiny::tags$div(
            class = 'world-controls',
            world_range_input(
              ns('scenario'),
              paste0(w$varying, ' (', w$units[[w$varying]], ')'),
              min = min(settings),
              max = max(settings),
              value = values$scenario %||% center,
              step = min(diff(settings)),
              values = settings
            ),
            shiny::numericInput(
              ns('threshold'),
              paste0('Outcome threshold (', w$outcome_units, ')'),
              value = values$threshold %||% w$threshold
            ),
            world_range_input(
              ns('realization'),
              'Simulated experiment',
              min = 1,
              max = length(w$expected),
              value = values$realization %||% 1,
              step = 1
            ),
            shiny::selectInput(
              ns('comparison'),
              'Compare against',
              comparisons,
              selected = values$comparison %||% 'none',
              selectize = FALSE
            )
          ),
          shiny::actionButton(ns('previous'), 'Previous experiment'),
          shiny::actionButton(ns('next_draw'), 'Next experiment')
        ),
        shiny::plotOutput(ns('plot'), height = '390px')
      ),
      shiny::uiOutput(ns('plot_description')),
      shiny::uiOutput(ns('consequences')),
      shiny::tags$p(
        class = 'world-step',
        '3 \u00b7 Decide what deserves a challenge'
      ),
      shiny::uiOutput(ns('implications')),
      shiny::actionButton(
        ns('discuss_model'),
        'Explore this model in conversation'
      ),
      shiny::tags$div(
        class = 'world-review',
        shiny::h3('Your interpretation'),
        shiny::p(
          'Keep your wording, position and proposed challenge with these exact model predictions. Acceptance here means accepting an interpretation; it does not establish that the model is true.'
        ),
        shiny::actionButton(
          ns('draft'),
          'Use this scenario as a starting statement'
        ),
        shiny::textAreaInput(
          ns('claim'),
          'What does the model imply?',
          value = values$claim %||% '',
          width = '100%'
        ),
        shiny::radioButtons(
          ns('position'),
          'Your position',
          c(
            'Accept this interpretation' = 'accept',
            'Qualify it' = 'qualify',
            'Challenge it' = 'challenge'
          ),
          selected = values$position %||% 'qualify',
          inline = TRUE
        ),
        shiny::textAreaInput(
          ns('reason'),
          'Why? Include the scope or correction that matters.',
          value = values$reason %||% '',
          width = '100%'
        ),
        shiny::textAreaInput(
          ns('challenge'),
          'What observation or measurement would probe this?',
          value = values$challenge %||% '',
          width = '100%'
        ),
        shiny::textInput(ns('author'), 'Your name', values$author %||% 'You'),
        shiny::checkboxInput(
          ns('reviewed'),
          'I reviewed the model, this scenario and my interpretation.',
          FALSE
        ),
        shiny::actionButton(
          ns('retain'),
          'Retain my interpretation',
          class = 'btn-primary'
        ),
        shiny::tags$div(
          class = 'world-status',
          role = 'status',
          shiny::textOutput(ns('status'))
        )
      ),
      shiny::uiOutput(ns('reviews')),
      shiny::actionButton(ns('discuss'), 'Discuss my latest challenge'),
      shiny::downloadButton(ns('save'), 'Save conversation and record'),
      shiny::tags$details(
        shiny::tags$summary('Bring your own model'),
        shiny::p(
          'Create a snapshot in R with inspect_model(fit, ...), supplying scenarios, units and scientific context, then open suppose_app(model = world). The initial adapter supports a bounded set of univariate brms models. Stan and tidymodels adapters are not yet available.'
        ),
        shiny::p(
          'The exported JSON contains predictions and reviews, not executable model objects. See the model-world guide for the full example and supported capabilities.'
        )
      ),
      shiny::tags$details(
        shiny::tags$summary('Model source and computation'),
        shiny::uiOutput(ns('provenance')),
        shiny::downloadButton(ns('example_code'), 'Download example R code')
      )
    )
  )
}

model_world_server <- function(
  id,
  current,
  guard,
  model = NULL,
  messages = function() list(),
  followup = function(text) NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    examples <- list(
      linear = suppose_model_example('linear'),
      curved = suppose_model_example('curved'),
      waiting = suppose_model_example('waiting')
    )
    status <- shiny::reactiveVal(
      'Starting models are simulations. Your interpretation is retained only after review.'
    )
    last <- shiny::reactiveVal(NULL)
    review_basis <- shiny::reactiveVal(NULL)
    handled <- shiny::reactiveValues()
    actions <- c(
      'next_draw',
      'previous',
      'draft',
      'retain',
      'discuss',
      'discuss_model'
    )
    action_once <- function(name) {
      value <- as.integer(input[[name]])
      if (
        !length(value) ||
          is.na(value) ||
          value <= 0 ||
          value <= (handled[[name]] %||% 0L)
      ) {
        return(FALSE)
      }
      handled[[name]] <- value
      TRUE
    }
    initialized <- shiny::reactiveVal(NULL)
    discard <- shiny::reactiveVal(TRUE)
    available <- shiny::reactive({
      worlds <- c(
        if (!is.null(model)) list(model),
        examples,
        current()$model_worlds
      )
      ids <- vapply(worlds, function(w) w$id, character(1))
      stats::setNames(worlds[!duplicated(ids)], ids[!duplicated(ids)])
    })
    shiny::observe({
      input$mounted
      ws <- available()
      choices <- stats::setNames(
        names(ws),
        vapply(ws, function(w) w$title, character(1))
      )
      selected <- shiny::isolate(input$model)
      if (is.null(selected) || !selected %in% names(ws)) {
        selected <- names(ws)[1]
      }
      shiny::updateSelectInput(
        session,
        'model',
        choices = choices,
        selected = selected
      )
    })
    world <- shiny::reactive({
      shiny::req(input$model)
      w <- available()[[input$model]]
      shiny::req(w)
      w
    })
    shiny::observeEvent(list(world()$id, input$mounted), {
      w <- world()
      key <- w$id
      if (identical(key, initialized())) {
        return()
      }
      initialized(key)
      n <- length(w$scenarios)
      vals <- vapply(w$scenarios, function(s) s[[w$varying]], numeric(1))
      center <- which.min(abs(vals - mean(w$training_range)))
      world_update_slider(
        session,
        'scenario',
        min = min(vals),
        max = max(vals),
        value = vals[center],
        step = min(diff(vals)),
        values = vals,
        label = paste(
          'Scenario along',
          w$varying,
          '(',
          w$units[[w$varying]],
          ')'
        )
      )
      world_update_slider(
        session,
        'realization',
        min = 1,
        max = length(w$expected),
        value = 1
      )
      shiny::updateNumericInput(
        session,
        'threshold',
        value = w$threshold,
        label = paste0('Outcome threshold (', w$outcome_units, ')')
      )
      ws <- Filter(
        function(other) world_comparable(w, other) && other$id != w$id,
        available()
      )
      choices <- c(
        'No comparison' = 'none',
        stats::setNames(
          names(ws),
          vapply(ws, function(z) z$title, character(1))
        )
      )
      shiny::updateSelectInput(
        session,
        'comparison',
        choices = choices,
        selected = 'none'
      )
      shiny::updateCheckboxInput(session, 'reviewed', value = FALSE)
      status(
        'Model changed. Review the new predictions before retaining an interpretation.'
      )
    })
    index <- shiny::reactive({
      shiny::req(input$scenario)
      which.min(abs(
        vapply(
          world()$scenarios,
          function(s) s[[world()$varying]],
          numeric(1)
        ) -
          input$scenario
      ))
    })
    draw <- shiny::reactive({
      shiny::req(input$realization)
      min(length(world()$expected), max(1L, as.integer(input$realization)))
    })
    threshold <- shiny::reactive({
      shiny::req(is.finite(input$threshold))
      input$threshold
    })
    comparison <- shiny::reactive({
      w <- available()[[input$comparison %||% 'none']]
      if (is.null(w) || !world_comparable(world(), w) || w$id == world()$id) {
        NULL
      } else {
        w
      }
    })
    review_payload <- function() {
      list(
        world()$id,
        index(),
        threshold(),
        draw(),
        comparison()$id,
        input$claim,
        input$position,
        input$reason,
        input$challenge,
        input$author
      )
    }
    shiny::observeEvent(
      input$reviewed,
      {
        review_basis(if (isTRUE(input$reviewed)) review_payload() else NULL)
      },
      priority = 90
    )
    shiny::observeEvent(
      list(
        input$scenario,
        input$threshold,
        input$realization,
        input$comparison,
        input$claim,
        input$reason,
        input$challenge,
        input$position,
        input$author
      ),
      {
        review_basis(NULL)
        shiny::updateCheckboxInput(session, 'reviewed', value = FALSE)
      },
      priority = 100,
      ignoreInit = TRUE
    )
    shiny::observeEvent(input$next_draw, {
      if (!action_once('next_draw')) {
        return()
      }
      world_update_slider(
        session,
        'realization',
        value = if (draw() == length(world()$expected)) 1 else draw() + 1L
      )
    })
    shiny::observeEvent(input$previous, {
      if (!action_once('previous')) {
        return()
      }
      world_update_slider(
        session,
        'realization',
        value = if (draw() == 1L) length(world()$expected) else draw() - 1L
      )
    })
    output$intro <- shiny::renderUI({
      w <- world()
      shiny::tagList(
        if (
          (w$provenance$max_rhat %||% Inf) > 1.01 ||
            (w$provenance$divergences %||% 1) > 0 ||
            (w$provenance$min_bulk_ess %||% 0) < 100
        ) {
          shiny::p(
            class = 'world-alert',
            'These computational diagnostics need attention. Inspect the original fit before relying on its predictions.'
          )
        },
        shiny::h3(w$title),
        shiny::p(w$scope),
        if (length(w$units) > 1) {
          shiny::p(paste(
            "Other predictors held fixed:",
            paste(
              vapply(
                setdiff(names(w$units), w$varying),
                function(n) paste(n, "=", w$scenarios[[1]][[n]], w$units[[n]]),
                character(1)
              ),
              collapse = "; "
            ),
            ". Unadjusted fitting points are omitted from this conditional view."
          ))
        },
        shiny::p(class = 'hint', w$source)
      )
    })
    output$structure <- shiny::renderUI({
      w <- world()
      shiny::tagList(
        shiny::tags$details(
          shiny::tags$summary(
            'Inspect formula, likelihood and conditional assumptions'
          ),
          shiny::tags$ul(lapply(w$structure, shiny::tags$li))
        ),
        shiny::p(
          shiny::strong('Scientific interpretation supplied by the author: '),
          w$assumptions
        )
      )
    })
    output$plot <- shiny::renderPlot(
      {
        plot_model_world(world(), index(), draw(), threshold(), comparison())
      },
      res = 110,
      alt = function() {
        w <- world()
        s <- world_summary(w, index(), threshold())
        sprintf(
          '%s. At %g %s, median expected outcome %.1f %s; central 90 percent interval for a future outcome %.1f to %.1f. Purple shared-draw curve and orange simulated outcomes show experiment %d. Bands are pointwise intervals. Fitting range %g to %g.',
          w$title,
          w$scenarios[[index()]][[w$varying]],
          w$units[[w$varying]],
          s$expected[2],
          w$outcome_units,
          s$future[1],
          s$future[3],
          draw(),
          w$training_range[1],
          w$training_range[2]
        )
      }
    )
    output$plot_description <- shiny::renderUI({
      w <- world()
      shiny::p(
        class = 'hint',
        paste(
          'Purple line: one coherent expected-response draw. Orange dots: one simulated outcome at each setting from that same draw. Shaded bands: pointwise central 90% intervals for expected responses and future outcomes; they are not simultaneous curve coverage. Gray dots, when shown: up to 1,000 fitting-data rows from a single-predictor model. Dashed vertical lines bound the supplied fitting range. Experiment',
          draw(),
          'of',
          length(w$expected),
          '.'
        )
      )
    })
    output$consequences <- shiny::renderUI({
      w <- world()
      s <- world_summary(w, index(), threshold())
      setting <- w$scenarios[[index()]][[w$varying]]
      shiny::tagList(
        shiny::h3(paste(
          'At',
          setting,
          w$units[[w$varying]],
          'with threshold',
          threshold(),
          w$outcome_units
        )),
        shiny::tags$div(
          class = 'world-facts',
          shiny::tags$div(
            class = 'world-fact',
            shiny::span('Uncertain average outcome'),
            shiny::strong(sprintf('%.1f %s', s$expected[2], w$outcome_units)),
            shiny::p(sprintf(
              'Central 90%% interval: %.1f to %.1f',
              s$expected[1],
              s$expected[3]
            )),
            shiny::p(sprintf(
              '%.1f%% of retained expected-response draws exceed the threshold.',
              100 * s$expected_above
            ))
          ),
          shiny::tags$div(
            class = 'world-fact',
            shiny::span('One future outcome'),
            shiny::strong(sprintf(
              '%.1f to %.1f %s',
              s$future[1],
              s$future[3],
              w$outcome_units
            )),
            shiny::p('Central 90% predictive interval'),
            shiny::p(sprintf(
              '%.1f%% of retained future-outcome draws exceed the threshold.',
              100 * s$future_above
            ))
          )
        ),
        if (!is.null(comparison())) {
          other <- comparison()
          os <- world_summary(other, index(), threshold())
          shiny::p(
            class = 'world-alert',
            sprintf(
              'Comparison: %s predicts a median average of %.1f %s here, with %.1f%% of future outcomes above %.1f %s. Both models use the same fitting data. This comparison does not refit or establish which model is adequate.',
              other$title,
              os$expected[2],
              w$outcome_units,
              100 * os$future_above,
              threshold(),
              w$outcome_units
            )
          )
        },
        shiny::p(
          class = 'hint',
          paste(
            'Monte Carlo estimates from',
            s$draws,
            'retained posterior draws. Simulation is not new evidence.'
          )
        )
      )
    })
    shiny::observeEvent(input$mounted, {
      discard(FALSE)
      for (name in actions) {
        handled[[name]] <- as.integer(input[[name]] %||% 0L)
      }
    })
    output$implications <- shiny::renderUI({
      w <- world()
      s <- world_summary(w, index(), threshold())
      value <- w$scenarios[[index()]][[w$varying]]
      outside <- value < w$training_range[1] || value > w$training_range[2]
      shiny::tagList(
        if (index() != s$reference_index) {
          shiny::p(sprintf(
            'Compared with %g %s, the modeled average at this setting differs by a median %.1f %s (central 90%% interval %.1f to %.1f). %.1f%% of shared parameter draws imply an increase. This compares conditional predictions; it does not identify an intervention effect.',
            w$scenarios[[s$reference_index]][[w$varying]],
            w$units[[w$varying]],
            s$change[2],
            w$outcome_units,
            s$change[1],
            s$change[3],
            100 * s$increase_fraction
          ))
        },
        shiny::p(
          class = if (outside) 'world-alert' else 'hint',
          if (outside) {
            'This scenario is outside the supplied fitting range. The prediction extends the chosen model structure; these fitting data do not directly check it here.'
          } else {
            'This scenario is within the supplied fitting range. That alone does not establish applicability, adequacy or a causal effect.'
          }
        ),
        if (!is.null(s$impossible)) {
          shiny::p(sprintf(
            '%.1f%% of simulated outcomes here fall below the supplied physical lower bound of %g %s. A zero count in this finite sample does not prove impossible outcomes have zero probability.',
            100 * s$impossible,
            w$lower_bound,
            w$outcome_units
          ))
        },
        shiny::p(
          'Would these outcomes make sense in your setting? Which part of the model, its scope, or the measurement process would you question?'
        )
      )
    })
    shiny::observeEvent(input$draft, {
      if (!action_once('draft')) {
        return()
      }
      w <- world()
      s <- world_summary(w, index(), threshold())
      shiny::updateTextAreaInput(
        session,
        'claim',
        value = sprintf(
          'Under %s, at %g %s the median expected %s is %.1f %s. This is a conditional model implication, not an observed or causal result.',
          w$title,
          w$scenarios[[index()]][[w$varying]],
          w$units[[w$varying]],
          w$response,
          s$expected[2],
          w$outcome_units
        )
      )
      shiny::updateCheckboxInput(session, 'reviewed', value = FALSE)
    })
    shiny::observeEvent(input$retain, {
      if (!action_once('retain')) {
        return()
      }
      tryCatch(
        {
          guard()
          w <- world()
          values <- review_payload()
          if (!isTRUE(input$reviewed) || !identical(values, review_basis())) {
            abort_suppose(
              'Review the current model, scenario and wording before retaining this interpretation.'
            )
          }
          if (identical(values, last())) {
            abort_suppose(
              'This interpretation was just retained. Revise the wording or challenge before retaining another.'
            )
          }
          c <- claim(
            input$claim,
            input$author,
            scope = w$scope,
            units = w$outcome_units,
            assumptions = w$assumptions,
            unresolved = input$challenge
          )
          base <- current()
          if (is.null(base)) {
            base <- elicitation_record(
              claim(
                paste('What world does', w$title, 'describe?'),
                input$author,
                scope = w$scope
              ),
              w$title
            )
          }
          next_record <- record_model_implication(
            base,
            w,
            c,
            input$position,
            input$reason,
            input$challenge,
            input$author,
            isTRUE(input$reviewed),
            scenario = index(),
            threshold = threshold(),
            realization = draw(),
            comparison = comparison()
          )
          current(next_record)
          last(values)
          shiny::updateCheckboxInput(session, 'reviewed', value = FALSE)
          status(
            'Interpretation and exact model predictions retained. Save the record to reopen them. The proposed challenge is not a frozen test.'
          )
        },
        error = function(e) status(conditionMessage(e))
      )
    })
    shiny::observeEvent(input$discuss_model, {
      if (!action_once('discuss_model')) {
        return()
      }
      tryCatch(
        {
          guard()
          w <- world()
          base <- current() %||% model_world_inquiry(w)
          base <- record_model_world(base, w)
          if (!is.null(comparison())) {
            base <- record_model_world(base, comparison())
          }
          current(base)
          s <- world_summary(w, index(), threshold())
          followup(sprintf(
            'Help me explore the world implied by %s at %g %s. Its median expected outcome here is %.1f %s, and %.1f%% of its saved future-outcome draws exceed %g %s. Which assumptions and consequences should I question?',
            w$title,
            w$scenarios[[index()]][[w$varying]],
            w$units[[w$varying]],
            s$expected[2],
            w$outcome_units,
            100 * s$future_above,
            threshold(),
            w$outcome_units
          ))
        },
        error = function(e) status(conditionMessage(e))
      )
    })
    shiny::observeEvent(input$discuss, {
      if (!action_once('discuss')) {
        return()
      }
      reviews <- current()$model_implications
      if (!length(reviews)) {
        status('Retain an interpretation and a proposed challenge first.')
        return()
      }
      r <- utils::tail(reviews, 1)[[1]]
      followup(paste0(
        'Help me explore my latest model interpretation: ',
        r$claim$wording,
        '\nMy reasoning: ',
        r$reason,
        '\nHow could we investigate this challenge? ',
        r$challenge
      ))
    })
    output$status <- shiny::renderText(status())
    output$reviews <- shiny::renderUI({
      reviews <- current()$model_implications
      if (!length(reviews)) {
        return(NULL)
      }
      shiny::tagList(
        shiny::h3('Retained interpretations'),
        lapply(rev(reviews), function(r) {
          w <- Filter(function(w) w$id == r$model_id, current()$model_worlds)[[
            1
          ]]
          shiny::tags$details(
            shiny::tags$summary(paste(r$position, '\u00b7', r$claim$wording)),
            shiny::p(paste(w$title, '\u00b7 reviewed by', r$author)),
            shiny::p(paste('Reason:', r$reason)),
            shiny::p(paste('Proposed challenge:', r$challenge)),
            shiny::p(paste(
              'Saved scenario:',
              w$scenarios[[r$scenario]][[w$varying]],
              w$units[[w$varying]],
              '\u00b7 threshold:',
              r$threshold,
              w$outcome_units
            )),
            shiny::p(
              class = 'hint',
              'This is an interpretation review, not evidence or a numerical test commitment.'
            )
          )
        })
      )
    })
    output$save <- shiny::downloadHandler(
      filename = function() 'suppose-model-inquiry.json',
      content = function(file) {
        shiny::req(current())
        write_record(record_conversation(current(), messages()), file)
      }
    )
    output$example_code <- shiny::downloadHandler(
      filename = function() 'build-model-worlds.R',
      content = function(file) {
        file.copy(
          system.file(
            'model-worlds',
            'build-model-worlds.R',
            package = 'suppose'
          ),
          file,
          overwrite = TRUE
        )
      }
    )
    output$provenance <- shiny::renderUI({
      w <- world()
      shiny::tagList(
        shiny::p(w$source),
        shiny::tags$pre(w$formula),
        shiny::tags$pre(w$priors),
        shiny::p(paste(
          'brms',
          w$provenance$version,
          '\u00b7 seed',
          w$provenance$seed,
          '\u00b7 maximum R-hat',
          round(w$provenance$max_rhat %||% NA_real_, 3),
          '\u00b7 divergences',
          w$provenance$divergences
        )),
        shiny::p(w$provenance$diagnostics),
        shiny::p(paste('Snapshot:', w$id)),
        shiny::p(paste('Model fingerprint:', w$provenance$model_hash)),
        shiny::tags$ul(lapply(w$limitations, shiny::tags$li))
      )
    })
    list(
      ui = function() {
        values <- if (shiny::isolate(discard())) {
          list()
        } else {
          shiny::isolate(shiny::reactiveValuesToList(input))
        }
        ws <- shiny::isolate(available())
        if (!length(values)) {
          latest <- utils::tail(shiny::isolate(current())$model_implications, 1)
          if (length(latest)) {
            r <- latest[[1]]
            values$model <- r$model_id
            values$scenario <- ws[[r$model_id]]$scenarios[[r$scenario]][[
              ws[[r$model_id]]$varying
            ]]
            values$threshold <- r$threshold
            values$realization <- r$realization
            values$comparison <- r$comparison_id %||% 'none'
          }
        }
        selected <- values$model
        if (is.null(selected) || !selected %in% names(ws)) {
          selected <- names(ws)[1]
        }
        initialized(selected)
        model_world_ui(id, ws, values)
      },
      reset = function() {
        discard(TRUE)
        initialized(NULL)
        last(NULL)
        review_basis(NULL)
        status(
          'Explore freely. Review a model implication before retaining it.'
        )
      }
    )
  })
}

world_comparable <- function(x, y) {
  identical(x$scenarios, y$scenarios) &&
    identical(x$outcome_units, y$outcome_units) &&
    identical(x$units, y$units) &&
    identical(x$response, y$response) &&
    identical(x$provenance$data_hash, y$provenance$data_hash)
}

#' Plot coherent outcomes from an external model snapshot
#'
#' Bands are pointwise central 90% intervals, not simultaneous curve coverage.
#' The curve and simulated outcomes share one retained posterior draw. The
#' optional comparison line is its median expected response, not a matched draw.
#' @param x A snapshot from [inspect_model()] or [suppose_model_example()].
#' @param scenario Scenario row to mark. Defaults to the row nearest the midpoint
#'   of the supplied fitting range.
#' @param realization Retained posterior draw to display.
#' @param threshold Meaningful response threshold in outcome units.
#' @param comparison Optional snapshot with identical fitting data, scenarios,
#'   response and units.
#' @return A ggplot object.
#' @export
#' @examples
#' if (requireNamespace('ggplot2', quietly = TRUE)) {
#'   plot_model_world(suppose_model_example('waiting'))
#' }
plot_model_world <- function(
  x,
  scenario = NULL,
  realization = 1L,
  threshold = x$threshold,
  comparison = NULL
) {
  rlang::check_installed('ggplot2')
  validate_model_world(x)
  if (is.null(scenario)) {
    settings <- vapply(x$scenarios, function(s) s[[x$varying]], numeric(1))
    scenario <- which.min(abs(settings - mean(x$training_range)))
  }
  check_count(scenario, 'scenario', 1, length(x$scenarios))
  check_count(realization, 'realization', 1, length(x$expected))
  check_number(threshold, 'threshold')
  if (!is.null(comparison)) {
    validate_model_world(comparison)
    if (!world_comparable(x, comparison)) {
      abort_suppose(
        'The comparison model needs the same fitting data, scenarios, response and units.'
      )
    }
  }
  index <- scenario
  draw <- realization

  d <- world_scenarios(x)
  a <- d[[x$varying]]
  e <- world_matrix(x, 'expected')
  y <- world_matrix(x, 'future')
  interval <- function(m, p) {
    apply(m, 2, stats::quantile, probs = p, names = FALSE)
  }
  frame <- data.frame(
    x = a,
    elo = interval(e, 0.05),
    ehi = interval(e, 0.95),
    ylo = interval(y, 0.05),
    yhi = interval(y, 0.95),
    curve = e[draw, ],
    outcome = y[draw, ]
  )
  p <- ggplot2::ggplot(frame, ggplot2::aes(x = .data$x)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$ylo, ymax = .data$yhi),
      fill = '#e6dbea',
      alpha = 0.65
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$elo, ymax = .data$ehi),
      fill = '#b7a0ce',
      alpha = 0.65
    ) +
    ggplot2::geom_hline(
      yintercept = threshold,
      color = '#826d30',
      linetype = 3
    ) +
    ggplot2::geom_vline(
      xintercept = x$training_range,
      linetype = 2,
      color = '#8b8490'
    ) +
    ggplot2::geom_vline(
      xintercept = a[index],
      color = '#b74d08',
      linewidth = 0.4
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = .data$curve),
      color = '#633b83',
      linewidth = 1
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = .data$outcome),
      color = '#b74d08',
      size = 1.6,
      alpha = 0.8
    ) +
    ggplot2::labs(
      x = paste0(x$varying, ' (', x$units[[x$varying]], ')'),
      y = paste0(x$response, ' (', x$outcome_units, ')')
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = '#fffdf9', color = NA)
    )
  if (length(x$fitting_points)) {
    pts <- do.call(rbind, lapply(x$fitting_points, as.data.frame))
    p <- p +
      ggplot2::geom_point(
        data = pts,
        ggplot2::aes(x = .data$x, y = .data$y),
        inherit.aes = FALSE,
        color = '#68606a',
        alpha = 0.45,
        size = 1.2
      )
  }
  if (!is.null(comparison)) {
    p <- p +
      ggplot2::geom_line(
        data = data.frame(
          x = a,
          y = apply(world_matrix(comparison, 'expected'), 2, stats::median)
        ),
        ggplot2::aes(x = .data$x, y = .data$y),
        inherit.aes = FALSE,
        color = '#197a75',
        linewidth = 1,
        linetype = 2
      ) +
      ggplot2::labs(
        caption = 'Teal dashed line: comparison model median expected response.'
      )
  }
  p
}
