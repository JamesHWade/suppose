workbench_form_values <- function(record, form, values) {
  if (
    !is.list(values) ||
      (length(values) &&
        (is.null(names(values)) || anyDuplicated(names(values))))
  ) {
    abort_suppose("Supply named form values.")
  }
  if (form == "extension") {
    defaults <- list(
      predictor = "Added predictor",
      predictor_units = "units",
      center = 0,
      scale = 1,
      effect_mean = 0,
      effect_sd = NULL,
      plausible_lower = NULL,
      plausible_upper = NULL
    )
  } else if (form == "sensitivity") {
    updates <- record$updates
    if (!length(updates)) {
      abort_suppose(
        "Retain an update before drafting sensitivity settings.",
        "incomplete"
      )
    }
    defaults <- list(
      update_id = utils::tail(updates, 1)[[1]]$id,
      powers = c(0.8, 1, 1.25),
      components = c("prior", "likelihood"),
      quantities = c("estimate", "probability", "assessment"),
      estimate_change = 1,
      probability_change = 0.05
    )
  } else if (form == "regression") {
    defaults <- regression_form_defaults(record)
  } else if (form == "design") {
    defaults <- research_design_defaults(record)
  } else if (form == "regression_test") {
    defaults <- regression_test_form_defaults(record)
  } else if (form == "regression_sensitivity") {
    defaults <- regression_sensitivity_form_defaults(record)
  } else if (form == "import") {
    defaults <- measurement_form_defaults(record)
  } else {
    abort_suppose("Choose a supported workbench form.")
  }
  if (!all(names(values) %in% names(defaults))) {
    abort_suppose("The draft contains unsupported form fields.")
  }
  for (name in names(values)) {
    defaults[name] <- values[name]
  }
  defaults
}

workbench_form_preview <- function(record, form, values) {
  values <- workbench_form_values(record, form, values)
  fit <- if (form == "extension") {
    do.call(compare_extension, c(list(x = record), values))
  } else if (form == "regression") {
    do.call(regression_prior, c(list(x = record), values))
  } else if (form == "import") {
    measurement_form_preview(record, values)
  } else if (form == "design") {
    research_design_form_preview(record, values)
  } else if (form == "regression_test") {
    regression_test_form_preview(record, values)
  } else if (form == "regression_sensitivity") {
    regression_sensitivity_form_preview(record, values)
  } else {
    do.call(sensitivity_analysis, c(list(x = record), values))
  }
  list(values = values, fit = fit)
}

stage_workbench_form <- function(state, form, values, source_quote, reason) {
  check_quote(source_quote, state$messages)
  check_text(reason, "reason")
  existing <- Filter(
    Negate(is.null),
    state$request$form_state[[form]]$values %||% list()
  )
  merged <- existing
  for (name in names(values)) {
    merged[name] <- values[name]
  }
  preview <- workbench_form_preview(state$request$base, form, merged)
  draft <- seal(
    list(
      form = form,
      base_id = proposal_basis_id(state$request$base),
      values = preview$values,
      provided_fields = names(values) %||% character(),
      preserved_fields = setdiff(names(existing), names(values)),
      form_base_id = state$request$form_state[[form]]$version,
      defaulted_fields = setdiff(
        names(preview$values),
        union(names(values), names(existing))
      ),
      source_quote = source_quote,
      reason = reason,
      status = "suggested; not adopted",
      context = NULL
    ),
    "suppose_form_draft"
  )
  state$request$form_drafts[[form]] <- draft
  list(
    form = form,
    values = if (form == "import") {
      preview$values[setdiff(names(preview$values), "csv_text")]
    } else {
      preview$values
    },
    defaulted_fields = draft$defaulted_fields,
    status = "A form draft is staged for the end of this response. Its suggested assumptions require human review; no scientific record has changed.",
    preview = if (form == "import") {
      list(
        rows = length(preview$fit$data$rows),
        missing_outcomes = length(preview$fit$data$missing_ids),
        predictors = preview$fit$predictors$units,
        status = "Review the table and mapping, then click Attach reviewed table. Nothing attached or fitted yet."
      )
    } else if (form == "extension") {
      list(
        assumptions = preview$fit$assumptions,
        contrast = preview$fit$matched_contrast
      )
    } else if (form == "regression") {
      list(
        assumptions = preview$fit$assumptions,
        settings = preview$fit$settings,
        transforms = preview$fit$transforms,
        prior_changes = preview$fit$prior_changes,
        status = "Prior predictions only; review and confirm independence in the form before fitting."
      )
    } else if (form == "regression_test") {
      list(
        rule = regression_test_text(preview$fit),
        assumptions = preview$fit$assumptions,
        status = "Preview only; the human must freeze before outcomes are seen."
      )
    } else if (form == "regression_sensitivity") {
      list(
        variants = preview$fit$variants,
        interpretation = preview$fit$interpretation
      )
    } else if (form == "design") {
      preview$fit
    } else {
      preview$fit$followup
    }
  )
}

workbench_form_tools <- function(id, guard, state, receipt) {
  list(
    ellmer::tool(
      function(
        predictor,
        source_quote,
        reason,
        predictor_units = NULL,
        center = NULL,
        scale = NULL,
        effect_mean = NULL,
        effect_sd = NULL,
        plausible_lower = NULL,
        plausible_upper = NULL
      ) {
        guard(id)
        values <- Filter(
          Negate(is.null),
          list(
            predictor = predictor,
            predictor_units = predictor_units,
            center = center,
            scale = scale,
            effect_mean = effect_mean,
            effect_sd = effect_sd,
            plausible_lower = plausible_lower,
            plausible_upper = plausible_upper
          )
        )
        result <- stage_workbench_form(
          state,
          "extension",
          values,
          source_quote,
          reason
        )
        receipt(
          "draft_model_extension",
          list(values = values, source_quote = source_quote, reason = reason),
          result
        )
      },
      "Prepare a reviewable form and comparison for adding one shared additive predictor to the current normal prior. Fill from conversation; omit routine settings to use labeled defaults. New values are suggestions, not attributed user beliefs or observations. Does not fit, apply, accept or retain a model. After completion the user can open /extend and review the prepared comparison.",
      arguments = list(
        predictor = ellmer::type_string(),
        source_quote = ellmer::type_string(
          "Exact quote from the user requesting or describing this change."
        ),
        reason = ellmer::type_string(
          "Scientific reason to consider this extension."
        ),
        predictor_units = ellmer::type_string(required = FALSE),
        center = ellmer::type_number(required = FALSE),
        scale = ellmer::type_number(
          "Positive meaningful change in predictor units, e.g. 10 minutes; default 1.",
          required = FALSE
        ),
        effect_mean = ellmer::type_number(
          "Suggested normal coefficient mean per meaningful change; default zero.",
          required = FALSE
        ),
        effect_sd = ellmer::type_number(
          "Suggested coefficient SD per meaningful change; omitted derives a starting spread from original mean uncertainty.",
          required = FALSE
        ),
        plausible_lower = ellmer::type_number(required = FALSE),
        plausible_upper = ellmer::type_number(required = FALSE)
      ),
      name = "draft_model_extension",
      annotations = inquiry_draft_annotations()
    ),
    ellmer::tool(
      function(
        source_quote,
        reason,
        update_id = NULL,
        powers = NULL,
        components = NULL,
        quantities = NULL,
        estimate_change = NULL,
        probability_change = NULL
      ) {
        guard(id)
        values <- Filter(
          Negate(is.null),
          list(
            update_id = update_id,
            powers = powers,
            components = components,
            quantities = quantities,
            estimate_change = estimate_change,
            probability_change = probability_change
          )
        )
        result <- stage_workbench_form(
          state,
          "sensitivity",
          values,
          source_quote,
          reason
        )
        receipt(
          "draft_sensitivity",
          list(values = values, source_quote = source_quote, reason = reason),
          result
        )
      },
      "Prepare sensitivity settings and a preview from conversation, using labeled defaults for omitted fields: latest update, both components, powers 0.8/1/1.25, all outputs, 1 outcome unit and 0.05 probability review thresholds. No analysis is retained until the user reviews it. Use /sensitivity to open the prepared form.",
      arguments = list(
        source_quote = ellmer::type_string(),
        reason = ellmer::type_string(),
        update_id = ellmer::type_string(required = FALSE),
        powers = ellmer::type_array(ellmer::type_number(), required = FALSE),
        components = ellmer::type_array(
          ellmer::type_string(),
          required = FALSE
        ),
        quantities = ellmer::type_array(
          ellmer::type_string(),
          required = FALSE
        ),
        estimate_change = ellmer::type_number(required = FALSE),
        probability_change = ellmer::type_number(
          "Absolute probability change, e.g. 0.05 for five percentage points.",
          required = FALSE
        )
      ),
      name = "draft_sensitivity",
      annotations = inquiry_draft_annotations()
    ),
    regression_form_tool(id, guard, state, receipt)
  )
}

form_draft_notice <- function(draft) {
  if (is.null(draft)) {
    return(NULL)
  }
  shiny::tags$details(
    shiny::tags$summary("Prepared from chat; review suggested values"),
    inquiry_field("Your request", draft$source_quote),
    inquiry_field("Chat supplied", draft$provided_fields),
    inquiry_field("Existing form values kept", draft$preserved_fields),
    inquiry_field("Defaults used", draft$defaulted_fields),
    shiny::tags$p(
      "These are starting suggestions, not adopted beliefs. You can edit them. Retaining the result preserves the original chat suggestion alongside the reviewed settings."
    )
  )
}
