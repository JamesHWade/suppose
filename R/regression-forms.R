regression_form_defaults <- function(record) {
  if (!length(record$predictors)) {
    abort_suppose(
      "Attach predictor measurements in Fit and compare models before preparing a regression.",
      "incomplete"
    )
  }
  d <- utils::tail(record$predictors, 1)[[1]]
  previous <- Filter(
    function(e) identical(e$result$spec$design_id, d$id),
    record$regressions
  )
  if (length(previous)) {
    spec <- utils::tail(previous, 1)[[1]]$result$spec
    return(c(
      list(design_id = d$id, predictors = spec$predictors),
      spec$settings
    ))
  }
  p <- utils::tail(record$revisions, 1)[[1]]$candidate
  list(
    design_id = d$id,
    predictors = names(d$units)[1],
    location = if (is.null(p)) 0 else mean(p$means),
    intercept_sd = if (is.null(p)) 10 else max(1, sqrt(mean(p$mean_sd^2))),
    effect_sd = if (is.null(p)) 5 else max(1, sqrt(mean(p$mean_sd^2))),
    noise_sd = if (is.null(p)) 5 else max(1, sqrt(mean(p$batch_sd^2))),
    noise_shape = 3
  )
}

regression_form_tool <- function(id, guard, state, receipt) {
  ellmer::tool(
    function(
      source_quote,
      reason,
      design_id = NULL,
      predictors = NULL,
      location = NULL,
      intercept_sd = NULL,
      effect_sd = NULL,
      noise_sd = NULL,
      noise_shape = NULL
    ) {
      guard(id)
      values <- Filter(
        Negate(is.null),
        list(
          design_id = design_id,
          predictors = predictors,
          location = location,
          intercept_sd = intercept_sd,
          effect_sd = effect_sd,
          noise_sd = noise_sd,
          noise_shape = noise_shape
        )
      )
      result <- stage_workbench_form(
        state,
        "regression",
        values,
        source_quote,
        reason
      )
      receipt(
        "draft_regression",
        list(values = values, source_quote = source_quote, reason = reason),
        result
      )
    },
    "Fill the Bayesian regression form and prepare prior predictions. Use the retained predictor dataset; choose one baseline predictor or two names in baseline/added order. Omitted settings preserve existing controls or use labeled starting values based on an existing prior, never realized outcomes. This is a new normal/inverse-gamma model with unknown common noise, not a conversion of the earlier fixed-noise model. The user reviews priors and confirms independence before fitting, then reviews predictive checks and exact LOO comparison before retaining. This tool neither fits nor retains anything. Do not infer independence or claim computation has occurred.",
    arguments = list(
      source_quote = ellmer::type_string("Exact user request."),
      reason = ellmer::type_string(
        "Scientific reason to examine this regression."
      ),
      design_id = ellmer::type_string(required = FALSE),
      predictors = ellmer::type_array(ellmer::type_string(), required = FALSE),
      location = ellmer::type_number(
        "Prior outcome mean at predictor reference values.",
        required = FALSE
      ),
      intercept_sd = ellmer::type_number(
        "Positive marginal prior SD for the reference mean.",
        required = FALSE
      ),
      effect_sd = ellmer::type_number(
        "Positive marginal coefficient SD per meaningful change, not per raw unit. All effect means are zero. Inspect the returned prior_changes: if they largely exclude the user's plausible useful change, flag the conflict and revise the suggested scale rather than claiming the data will fix it.",
        required = FALSE
      ),
      noise_sd = ellmer::type_number(
        "Positive square root of prior expected measurement variance.",
        required = FALSE
      ),
      noise_shape = ellmer::type_number(
        "Inverse-gamma shape greater than 2; default 3.",
        required = FALSE
      )
    ),
    name = "draft_regression"
  )
}
