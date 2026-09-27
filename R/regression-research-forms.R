regression_review_model_id <- function(x) {
  entries <- Filter(function(e) e$choice != "neither", x$regressions)
  if (!length(entries)) {
    abort_suppose(
      "Retain a chosen regression before preparing this review.",
      "incomplete"
    )
  }
  utils::tail(entries, 1)[[1]]$id
}

regression_test_form_defaults <- function(x) {
  list(
    regression_id = regression_review_model_id(x),
    planned_csv = "",
    source = "",
    protocol = "",
    horizon = paste0(Sys.Date() + 7, "T23:59:59Z"),
    target = "",
    design = "observational",
    design_details = "",
    rule = "joint_outcomes",
    coverage = 0.9,
    plan_id = "",
    replaces = ""
  )
}

regression_sensitivity_form_defaults <- function(x) {
  list(
    regression_id = regression_review_model_id(x),
    contrast_csv = "",
    powers = c(0.8, 1, 1.25),
    components = c("prior", "likelihood"),
    meaningful_gain = 0,
    design_id = "",
    utility_thresholds = numeric(),
    estimate_change = 1,
    probability_change = 0.05,
    draws = 1000,
    seed = 1
  )
}

regression_test_form_preview <- function(x, v) {
  planned <- measurement_table(v$planned_csv)
  for (name in setdiff(names(planned), c("observation_id", "condition"))) {
    planned[[name]] <- suppressWarnings(as.numeric(planned[[name]]))
  }
  v$planned_csv <- NULL
  for (name in c("plan_id", "replaces")) {
    if (!nzchar(v[[name]])) v[name] <- list(NULL)
  }
  do.call(plan_regression_test, c(list(x = x, planned = planned), v))
}

regression_sensitivity_form_preview <- function(x, v) {
  contrast <- measurement_table(v$contrast_csv)
  contrast[] <- lapply(contrast, function(z) suppressWarnings(as.numeric(z)))
  v$contrast_csv <- NULL
  if (!nzchar(v$design_id)) {
    v["design_id"] <- list(NULL)
  }
  if (!length(v$utility_thresholds)) {
    v["utility_thresholds"] <- list(NULL)
  }
  do.call(sensitivity_regression, c(list(x = x, contrast = contrast), v))
}

regression_research_tools <- function(id, guard, state, receipt) {
  list(
    ellmer::tool(
      function(
        source_quote,
        reason,
        planned_csv = NULL,
        source = NULL,
        protocol = NULL,
        horizon = NULL,
        target = NULL,
        design_details = NULL,
        regression_id = NULL,
        design = NULL,
        rule = NULL,
        coverage = NULL,
        plan_id = NULL,
        replaces = NULL
      ) {
        guard(id)
        values <- Filter(
          Negate(is.null),
          list(
            planned_csv = planned_csv,
            source = source,
            protocol = protocol,
            horizon = horizon,
            target = target,
            design_details = design_details,
            regression_id = regression_id,
            design = design,
            rule = rule,
            coverage = coverage,
            plan_id = plan_id,
            replaces = replaces
          )
        )
        result <- stage_workbench_form(
          state,
          "regression_test",
          values,
          source_quote,
          reason
        )
        receipt(
          "draft_regression_test",
          list(values = values, source_quote = source_quote, reason = reason),
          result
        )
      },
      "Prepare a future regression test for human review only. Never freeze or assess via this tool. Preserve current form fields when editing one assumption. Exact future IDs, predictor settings in original units, source, protocol, deadline and collection/assignment rules are required. joint_outcomes checks all outcomes with one joint Student-t prediction region; mean_difference checks the future sample mean B minus A and requires A/B labels. Both integrate unknown noise and require complete cohorts. Do not invent independence, prior lack of exposure, safe settings or protocol adherence. A retained research plan can be referenced only if its chosen setting and replicate count match. Use the regression test form, not the older fixed-noise form.",
      arguments = list(
        source_quote = ellmer::type_string("Exact user request."),
        reason = ellmer::type_string(),
        planned_csv = ellmer::type_string(
          "CSV: observation_id,condition,selected model predictors; future settings only, no outcomes.",
          required = FALSE
        ),
        source = ellmer::type_string(required = FALSE),
        protocol = ellmer::type_string(required = FALSE),
        horizon = ellmer::type_string(
          "Future collection deadline as UTC ISO8601.",
          required = FALSE
        ),
        target = ellmer::type_string(
          "Scientific target and what the outcomes could challenge.",
          required = FALSE
        ),
        design_details = ellmer::type_string(
          "Sampling or assignment procedure and limitations.",
          required = FALSE
        ),
        regression_id = ellmer::type_string(required = FALSE),
        design = ellmer::type_string(
          "observational or intervention",
          required = FALSE
        ),
        rule = ellmer::type_string(
          "joint_outcomes or mean_difference",
          required = FALSE
        ),
        coverage = ellmer::type_number("0.01 to 0.999", required = FALSE),
        plan_id = ellmer::type_string(
          "Optional matching retained plan ID, or empty to clear.",
          required = FALSE
        ),
        replaces = ellmer::type_string(
          "Earlier regression commitment, or empty.",
          required = FALSE
        )
      ),
      name = "draft_regression_test",
      annotations = inquiry_draft_annotations()
    ),
    ellmer::tool(
      function(
        source_quote,
        reason,
        regression_id = NULL,
        contrast_csv = NULL,
        powers = NULL,
        components = NULL,
        meaningful_gain = NULL,
        design_id = NULL,
        utility_thresholds = NULL,
        estimate_change = NULL,
        probability_change = NULL,
        draws = NULL,
        seed = NULL
      ) {
        guard(id)
        values <- Filter(
          Negate(is.null),
          list(
            regression_id = regression_id,
            contrast_csv = contrast_csv,
            powers = powers,
            components = components,
            meaningful_gain = meaningful_gain,
            design_id = design_id,
            utility_thresholds = utility_thresholds,
            estimate_change = estimate_change,
            probability_change = probability_change,
            draws = draws,
            seed = seed
          )
        )
        result <- stage_workbench_form(
          state,
          "regression_sensitivity",
          values,
          source_quote,
          reason
        )
        receipt(
          "draft_regression_sensitivity",
          list(values = values, source_quote = source_quote, reason = reason),
          result
        )
      },
      "Prepare a regression-specific sensitivity comparison for review. Powers perturb the full joint coefficient/variance prior or full Gaussian likelihood separately, in the original beta/variance parameterization; improper powers are rejected. Keep observations, transforms and model choice fixed. Compare a mean contrast, noise and predictive diagnostics; optionally compare a retained plan's design rankings. meaningful_gain is a scientific threshold, while utility_thresholds changes only explicit decision preferences under the original posterior. Keep them distinct. Nothing is retained automatically, and unchanged rankings in a few variants do not prove robustness.",
      arguments = list(
        source_quote = ellmer::type_string(),
        reason = ellmer::type_string(),
        regression_id = ellmer::type_string(required = FALSE),
        contrast_csv = ellmer::type_string(
          "Two rows containing the chosen predictors in original units; B minus A.",
          required = FALSE
        ),
        powers = ellmer::type_array(ellmer::type_number(), required = FALSE),
        components = ellmer::type_array(
          ellmer::type_string(),
          required = FALSE
        ),
        meaningful_gain = ellmer::type_number(required = FALSE),
        design_id = ellmer::type_string(
          "Reviewed research-plan ID, or empty to clear.",
          required = FALSE
        ),
        utility_thresholds = ellmer::type_array(
          ellmer::type_number(),
          required = FALSE
        ),
        estimate_change = ellmer::type_number(required = FALSE),
        probability_change = ellmer::type_number(required = FALSE),
        draws = ellmer::type_number(required = FALSE),
        seed = ellmer::type_number(required = FALSE)
      ),
      name = "draft_regression_sensitivity",
      annotations = inquiry_draft_annotations()
    )
  )
}

regression_test_text <- function(c) {
  p <- c$prediction
  if (c$rule == "mean_difference") {
    sprintf(
      "Frozen rule: future sample mean B minus A in [%.3g, %.3g] %s, with %.1f%% predictive probability. Includes measurement noise; it does not test the unobserved population mean directly. All %d measurements are required.",
      p$contrast$lower,
      p$contrast$upper,
      p$units,
      100 * p$coverage,
      length(c$planned)
    )
  } else {
    sprintf(
      "Frozen rule: all %d outcomes are checked together against one %.1f%% joint prediction region (Student-t, %.1f degrees of freedom). Joint squared distance must be no greater than %.4g. Marginal intervals are not the simultaneous rule.",
      length(c$planned),
      100 * p$coverage,
      p$df,
      p$joint_cutoff
    )
  }
}
