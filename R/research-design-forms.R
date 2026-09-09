research_design_defaults <- function(record) {
  entries <- Filter(function(e) e$choice != "neither", record$regressions)
  if (!length(entries)) {
    abort_suppose(
      "Retain a chosen regression model before planning research.",
      "incomplete"
    )
  }
  list(
    regression_id = utils::tail(entries, 1)[[1]]$id,
    candidates_csv = "",
    contrast_csv = "",
    purpose = "estimate",
    threshold = 0,
    max_units = 6,
    rationale = "",
    preference = "",
    source_plan_id = NULL
  )
}

research_design_form_preview <- function(record, values) {
  candidates <- measurement_table(values$candidates_csv)
  contrast <- measurement_table(values$contrast_csv)
  for (name in setdiff(names(candidates), c("candidate_id", "feasible"))) {
    candidates[[name]] <- suppressWarnings(as.numeric(candidates[[name]]))
  }
  if (
    !"feasible" %in% names(candidates) ||
      anyNA(candidates$feasible) ||
      !all(candidates$feasible %in% c("TRUE", "FALSE"))
  ) {
    abort_suppose(
      "Use explicit TRUE or FALSE in the candidate feasible column."
    )
  }
  candidates$feasible <- candidates$feasible == "TRUE"
  contrast[] <- lapply(contrast, function(x) suppressWarnings(as.numeric(x)))
  do.call(
    design_regression,
    c(
      list(x = record, candidates = candidates, contrast = contrast),
      values[setdiff(names(values), c("candidates_csv", "contrast_csv"))]
    )
  )
}

research_design_tool <- function(id, guard, state, receipt) {
  ellmer::tool(
    function(
      source_quote,
      reason,
      candidates_csv = NULL,
      contrast_csv = NULL,
      regression_id = NULL,
      purpose = NULL,
      threshold = NULL,
      max_units = NULL,
      rationale = NULL,
      preference = NULL
    ) {
      guard(id)
      values <- Filter(
        Negate(is.null),
        list(
          candidates_csv = candidates_csv,
          contrast_csv = contrast_csv,
          regression_id = regression_id,
          purpose = purpose,
          threshold = threshold,
          max_units = max_units,
          rationale = rationale,
          preference = preference
        )
      )
      result <- stage_workbench_form(
        state,
        "design",
        values,
        source_quote,
        reason
      )
      receipt(
        "draft_research_design",
        list(values = values, source_quote = source_quote, reason = reason),
        result
      )
    },
    "Prepare exact Bayesian experimental design from a retained chosen regression. Compare alternative single-setting experiments with independent replicates. The target is protocol B mean minus A mean (the two contrast CSV rows). estimate reduces contrast variance; decide reduces opportunity loss between A and B using an explicit outcome-equivalent utility threshold. Never equate a scientific usefulness bar with economic utility without the user's explicit preference. Candidate cost is total experiment cost in squared outcome units for estimate or outcome-equivalent utility for decide; zero means ignore costs under unit budget, and must be disclosed. Do not infer safe feasible settings or independence. Candidate settings may be proposed but remain assumptions for human review. Explain existing model-check concerns. Returns a preview only; /design opens review. No campaign execution or prospective test is frozen.",
    arguments = list(
      source_quote = ellmer::type_string("Exact user request."),
      reason = ellmer::type_string(),
      candidates_csv = ellmer::type_string(
        "CSV header candidate_id, selected model predictor columns, repeats,cost,feasible. Each row an alternative, repeats integer 1..100, total cost >=0, feasible TRUE or FALSE. Use original predictor units. No observed outcomes.",
        required = FALSE
      ),
      contrast_csv = ellmer::type_string(
        "Two-row CSV containing exactly the chosen model predictors, original units. First row protocol A, second B. Other predictors held fixed for a one-predictor contrast.",
        required = FALSE
      ),
      regression_id = ellmer::type_string(required = FALSE),
      purpose = ellmer::type_string("estimate or decide", required = FALSE),
      threshold = ellmer::type_number(
        "Explicit B-minus-A utility hurdle; zero for estimate. Not automatically an energy price or scientific usefulness bar.",
        required = FALSE
      ),
      max_units = ellmer::type_number(
        "Available independent measurement units, integer 1..100.",
        required = FALSE
      ),
      rationale = ellmer::type_string(
        "Scientific purpose, collection protocol, feasibility and cost assumptions for review.",
        required = FALSE
      ),
      preference = ellmer::type_string(
        "Required for decide: user-stated indifference threshold and linear outcome-equivalent utility rationale; retain uncertainty about economics.",
        required = FALSE
      )
    ),
    name = "draft_research_design"
  )
}

research_plan_form_values <- function(x, id) {
  v <- research_design_settings(x, id)
  csv <- function(d) {
    paste(
      utils::capture.output(utils::write.csv(d, row.names = FALSE)),
      collapse = "\n"
    )
  }
  v$candidates_csv <- csv(v$candidates)
  v$contrast_csv <- csv(v$contrast)
  v[c("candidates", "contrast")] <- NULL
  v
}
