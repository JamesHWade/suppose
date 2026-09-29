# Record tools in the drawer, including the forms chat can prepare. Returns
# the forms' current values for chat drafts, a restore for drafts saved with
# a conversation, and the model-world walkthrough.
inquiry_forms_server <- function(
  input,
  output,
  session,
  state,
  assistant,
  busy,
  model
) {
  current <- state$current
  proposal <- state$proposal
  forms <- state$forms
  status <- state$status
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
  research_guard <- function() {
    busy()
    if (!is.null(proposal())) {
      abort_suppose(
        "Apply or decline the pending interpretation before reviewing regression research."
      )
    }
  }
  world_controller <- model_world_server(
    "world",
    current,
    research_guard,
    model,
    messages = function() assistant$messages,
    followup = function(text) {
      shiny::removeModal()
      shinychat::update_chat_user_input(
        "inquiry",
        value = text,
        focus = TRUE,
        session = session
      )
    }
  )
  regression_test_controller <- regression_review_server(
    "regression_test",
    current,
    research_guard,
    "regression_test",
    draft = shiny::reactive(forms()$regression_test),
    author = function() input$author %||% "You",
    retained = function() clear_form("regression_test")
  )
  regression_sensitivity_controller <- regression_review_server(
    "regression_sensitivity",
    current,
    research_guard,
    "regression_sensitivity",
    draft = shiny::reactive(forms()$regression_sensitivity),
    author = function() input$author %||% "You",
    retained = function() clear_form("regression_sensitivity")
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
  list(
    # What chat drafts start from, so a draft keeps values the person entered.
    form_state = function() {
      list(
        extension = extension_controller$form_state(),
        sensitivity = sensitivity_controller$form_state(),
        import = import_controller$form_state(),
        design = design_controller$form_state(),
        regression_test = regression_test_controller$form_state(),
        regression_sensitivity = regression_sensitivity_controller$form_state(),
        regression = regression_controller$form_state()
      )
    },
    # Drafts saved with a conversation, restored after the record is.
    restore = function(saved, record) {
      if (!is.null(saved$extension)) {
        extension_controller$restore(saved$extension)
      }
      if (!is.null(saved$sensitivity)) {
        sensitivity_controller$restore(saved$sensitivity)
      }
      if (!is.null(saved$regression)) {
        regression_controller$restore(saved$regression)
      } else if (length(record$predictors)) {
        regression_controller$restore_settings()
      }
      if (!is.null(saved$design)) {
        design_controller$restore(saved$design)
      }
      if (!is.null(saved$regression_test)) {
        regression_test_controller$restore(saved$regression_test)
      }
      if (!is.null(saved$regression_sensitivity)) {
        regression_sensitivity_controller$restore(
          saved$regression_sensitivity
        )
      }
      if (!is.null(saved$import)) {
        import_controller$restore(saved$import)
      }
    },
    world = world_controller
  )
}
