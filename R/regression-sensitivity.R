regression_power_posterior <- function(
  design,
  y,
  prior,
  prior_power,
  likelihood_power
) {
  p <- length(prior$mean)
  # Power the joint density in (beta, variance), including its variance exponent.
  a <- prior_power * (prior$shape + 1 + p / 2) - 1 - p / 2
  if (!is.finite(a) || a <= 0) {
    abort_suppose(
      "This prior power makes the joint normal/inverse-gamma prior improper. Use a power closer to one.",
      "properness"
    )
  }
  precision <- diag(prior_power / prior$v_diagonal)
  v <- chol2inv(chol(precision + likelihood_power * crossprod(design)))
  mean <- drop(
    v %*% (precision %*% prior$mean + likelihood_power * crossprod(design, y))
  )
  delta <- mean - prior$mean
  residual <- y - drop(design %*% mean)
  rate <- prior_power *
    prior$rate +
    (likelihood_power *
      sum(residual^2) +
      sum(delta * drop(precision %*% delta))) /
      2
  shape <- a + likelihood_power * length(y) / 2
  if (!all(is.finite(c(v, mean, rate, shape))) || rate <= 0 || shape <= 1) {
    abort_suppose(
      "The perturbed posterior must have finite expected variance and finite parameters.",
      "computation"
    )
  }
  list(mean = mean, v = v, shape = shape, rate = rate)
}

regression_design_variant <- function(entry, settings, post, threshold) {
  rlang::check_installed(
    "alloptr",
    reason = "to compare research-design sensitivity"
  )
  fields <- regression_selected_fit(entry)$terms[-1]
  matrix_for <- function(d) {
    regression_model_matrix(
      list(predictors = as.list(d[fields])),
      entry$result$spec$transforms,
      fields
    )
  }
  target <- matrix_for(settings$contrast)
  c <- drop(target[2, ] - target[1, ])
  candidates <- settings$candidates
  computation <- alloptr::bed_normal_contrast(
    post$mean,
    post$v,
    post$shape,
    post$rate,
    matrix_for(candidates),
    c,
    candidates$repeats,
    threshold
  )
  loss <- if (settings$purpose == "estimate") {
    computation$current$contrast_variance
  } else {
    computation$current$opportunity_loss
  }
  gains <- computation$scores[[
    if (settings$purpose == "estimate") "variance_gain" else "decision_gain"
  ]]
  net <- gains - candidates$cost
  eligible <- candidates$feasible & candidates$repeats <= settings$max_units
  best <- if (any(eligible)) max(net[eligible]) else 0
  tolerance <- 1e-10 * max(1, loss, abs(best))
  recommended <- if (best > tolerance) {
    candidates$candidate_id[eligible & abs(net - best) <= tolerance]
  } else {
    character()
  }
  list(
    purpose = settings$purpose,
    threshold = threshold,
    current_loss = loss,
    recommended = recommended,
    numerical_tolerance = tolerance,
    candidates = lapply(seq_len(nrow(candidates)), function(i) {
      list(
        candidate_id = candidates$candidate_id[i],
        eligible = eligible[i],
        benefit = gains[i],
        cost = candidates$cost[i],
        net_benefit = net[i]
      )
    }),
    interpretation = "Exact expected benefits conditional on this variant, with unchanged experiment settings, costs, feasibility and budget. Empty recommendations mean no positive net benefit; equal best scores at numerical resolution remain tied."
  )
}

#' Review regression and research-design sensitivity
#'
#' Perturbs one component at a time and solves each posterior exactly. Prior
#' power scales the full joint density in coefficients and variance, in that
#' parameterization; it is not equivalent to changing a marginal coefficient SD.
#' For p coefficients and inverse-gamma shape a, the powered prior shape is
#' `power * (a + 1 + p/2) - 1 - p/2`. Improper variants are rejected.
#' Likelihood power scales the full Gaussian likelihood, including its variance
#' normalization. Predictive checks still simulate the original measurement model.
#'
#' All variants use identical observations, predictors, transformations and model
#' choice. Optional utility thresholds change only decision preferences, under
#' the unperturbed posterior; they are not presented as model sensitivity.
#' No original fit, review, research plan or frozen test is changed.
#' @param x Record with a retained chosen regression.
#' @param regression_id Reviewed regression-entry ID.
#' @param contrast Two rows in original predictor units; second minus first.
#' @param powers Positive powers to inspect, 0.1 to 2; default 0.8, 1, 1.25.
#' @param components `prior`, `likelihood`, or both, varied separately.
#' @param meaningful_gain Scientifically meaningful contrast threshold, in outcome
#'   units. This is separate from any downstream utility preference.
#' @param design_id Optional retained research-plan ID for candidate ranking checks.
#' @param utility_thresholds Optional outcome-equivalent preference thresholds;
#'   requires a decision-purpose plan and varies utility only.
#' @param estimate_change,probability_change Review thresholds for changes in
#'   the contrast estimate and threshold probability (absolute probability units).
#' @param draws,seed Predictive-check replicates (200 to 5000) and explicit seed.
#' @return A sealed comparison with variants, exact contrast/noise summaries,
#'   predictive diagnostics, optional design rankings, and review flags.
#' @export
sensitivity_regression <- function(
  x,
  regression_id,
  contrast,
  powers = c(0.8, 1, 1.25),
  components = c("prior", "likelihood"),
  meaningful_gain = 0,
  design_id = NULL,
  utility_thresholds = NULL,
  estimate_change = 1,
  probability_change = 0.05,
  draws = 1000,
  seed = 1
) {
  validate_record(x)
  entry <- research_regression(x, regression_id)
  research_current_model(x, entry)
  f <- regression_selected_fit(entry)
  check_count(draws, "draws", 200, 5000)
  check_count(seed, "seed", 0, .Machine$integer.max)
  check_number(meaningful_gain, "meaningful_gain")
  check_number(estimate_change, "estimate_change", 0)
  check_number(probability_change, "probability_change", 0, 1)
  if (
    !is.numeric(powers) ||
      !length(powers) ||
      length(powers) > 9 ||
      any(!is.finite(powers) | powers < 0.1 | powers > 2) ||
      anyDuplicated(powers)
  ) {
    abort_suppose(
      "Choose one to nine distinct powers between 0.1 and 2.",
      "powers"
    )
  }
  check_strings(components, "components")
  if (
    !length(components) ||
      anyDuplicated(components) ||
      !all(components %in% c("prior", "likelihood"))
  ) {
    abort_suppose(
      "Choose prior, likelihood, or both as separate components.",
      "components"
    )
  }
  if (!is.data.frame(contrast) || nrow(contrast) != 2L) {
    abort_suppose("Supply two settings for the mean contrast.", "contrast")
  }
  predict_regression(entry$result, contrast, entry$choice)
  matrix_for <- function(predictors) {
    regression_model_matrix(
      list(predictors = predictors),
      entry$result$spec$transforms,
      f$terms[-1]
    )
  }
  design <- matrix_for(entry$result$predictor_values)
  target <- matrix_for(as.list(contrast))
  c <- drop(target[2, ] - target[1, ])
  if (all(c == 0)) {
    abort_suppose(
      "Choose different settings for the mean contrast.",
      "contrast"
    )
  }
  y <- as.numeric(unlist(entry$result$observed))
  prior <- Filter(
    function(p) identical(p$label, entry$choice),
    entry$result$spec$priors
  )[[1]]
  settings <- if (is.null(design_id)) {
    NULL
  } else {
    research_design_settings(x, design_id)
  }
  if (!is.null(settings) && !identical(settings$regression_id, regression_id)) {
    abort_suppose(
      "The research plan must use this exact reviewed regression.",
      "reference"
    )
  }
  if (!is.null(utility_thresholds)) {
    if (
      is.null(settings) ||
        settings$purpose != "decide" ||
        !is.numeric(utility_thresholds) ||
        !length(utility_thresholds) ||
        length(utility_thresholds) > 9L ||
        !all(is.finite(utility_thresholds)) ||
        anyDuplicated(utility_thresholds)
    ) {
      abort_suppose(
        "Utility sensitivity needs a decision-purpose plan and one to nine distinct finite thresholds.",
        "utility"
      )
    }
  }
  requests <- list(list(
    component = "reference",
    power = 1,
    threshold = settings$threshold %||% 0
  ))
  for (component in components) {
    for (power in powers[powers != 1]) {
      requests <- c(
        requests,
        list(list(
          component = component,
          power = power,
          threshold = settings$threshold %||% 0
        ))
      )
    }
  }
  for (threshold in utility_thresholds) {
    requests <- c(
      requests,
      list(list(component = "utility", power = 1, threshold = threshold))
    )
  }
  variants <- lapply(requests, function(request) {
    post <- regression_power_posterior(
      design,
      y,
      prior,
      if (request$component == "prior") request$power else 1,
      if (request$component == "likelihood") request$power else 1
    )
    mean <- sum(c * post$mean)
    scale <- sqrt(max(0, drop(t(c) %*% post$v %*% c) * post$rate / post$shape))
    q <- stats::qt(0.95, 2 * post$shape)
    checks <- if (request$component == "utility") {
      NULL
    } else {
      regression_ppc(
        list(y = y, predictors = entry$result$predictor_values),
        design,
        post,
        draws,
        seed
      )
    }
    list(
      component = request$component,
      power = request$power,
      contrast = list(
        mean = mean,
        lower = mean - q * scale,
        upper = mean + q * scale,
        probability_above = if (scale == 0) {
          as.numeric(mean > meaningful_gain)
        } else {
          stats::pt(
            (meaningful_gain - mean) / scale,
            df = 2 * post$shape,
            lower.tail = FALSE
          )
        }
      ),
      noise = list(
        median = sqrt(1 / stats::qgamma(0.5, post$shape, rate = post$rate)),
        lower = sqrt(1 / stats::qgamma(0.95, post$shape, rate = post$rate)),
        upper = sqrt(1 / stats::qgamma(0.05, post$shape, rate = post$rate))
      ),
      posterior = list(
        mean = post$mean,
        v = regression_matrix_rows(post$v),
        shape = post$shape,
        rate = post$rate
      ),
      checks = lapply(checks, function(c) c[setdiff(names(c), "replicated")]),
      design = if (is.null(settings)) {
        NULL
      } else {
        regression_design_variant(entry, settings, post, request$threshold)
      }
    )
  })
  reference <- variants[[1]]
  variants <- lapply(variants, function(v) {
    v$change <- list(
      estimate = v$contrast$mean - reference$contrast$mean,
      probability = v$contrast$probability_above -
        reference$contrast$probability_above,
      recommendation_changed = if (is.null(settings)) {
        FALSE
      } else {
        !setequal(v$design$recommended, reference$design$recommended)
      }
    )
    v$review_flag <- abs(v$change$estimate) > estimate_change ||
      abs(v$change$probability) > probability_change ||
      v$change$recommendation_changed
    v
  })
  seal(
    list(
      record_id = x$record_id,
      basis_id = proposal_basis_id(x),
      regression_id = regression_id,
      fit_id = entry$result$id,
      model = entry$choice,
      observation_ids = entry$result$spec$observation_ids,
      contrast = lapply(seq_len(2), function(i) {
        as.list(contrast[i, , drop = FALSE])
      }),
      units = entry$result$spec$units,
      meaningful_gain = meaningful_gain,
      powers = powers,
      components = components,
      design_id = design_id,
      utility_thresholds = utility_thresholds,
      estimate_change = estimate_change,
      probability_change = probability_change,
      variants = variants,
      draws = draws,
      seed = seed,
      method = "exact-joint-normal-inverse-gamma-power-sensitivity-v1",
      interpretation = c(
        "One component changes at a time. Power one is the original model. Prior power acts on the joint beta/variance density in its declared parameterization; it does not cover alternative model families or dependence assumptions.",
        "Utility variants keep the original posterior and change only the explicit preference threshold. Experiment costs and feasible settings stay fixed.",
        "Predictive-check tail areas have finite simulation uncertainty. Exact contrast probabilities and design scores do not use Monte Carlo estimates.",
        "A few unflagged variants do not establish robustness. Original reviews and frozen tests remain unchanged."
      ),
      created_at = now_utc()
    ),
    "suppose_regression_sensitivity"
  )
}

#' Retain a reviewed regression sensitivity comparison
#' @param x Record used for the comparison.
#' @param sensitivity Result from [sensitivity_regression()].
#' @param author,reason Reviewer and interpretation of consequential changes.
#' @param reviewed Explicit confirmation of reviewing variants and limitations.
#' @param form_draft Optional original chat draft as provenance.
#' @return Record with an appended comparison; original fits and plans unchanged.
#' @export
record_regression_sensitivity <- function(
  x,
  sensitivity,
  author,
  reason,
  reviewed = FALSE,
  form_draft = NULL
) {
  validate_record(x)
  check_seal(sensitivity, "suppose_regression_sensitivity")
  check_text(author, "author")
  check_text(reason, "reason")
  if (!isTRUE(reviewed)) {
    abort_suppose(
      "Review sensitivity variants and their limitations before retaining.",
      "review"
    )
  }
  if (!identical(sensitivity$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Recompute regression sensitivity before retaining.",
      "stale"
    )
  }
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      form_draft$form != "regression_sensitivity" ||
        !identical(form_draft$base_id, sensitivity$basis_id)
    ) {
      abort_suppose("Sensitivity draft references disagree.", "reference")
    }
  }
  x$regression_sensitivities <- c(
    x$regression_sensitivities,
    list(seal(
      list(
        result = sensitivity,
        author = author,
        reason = reason,
        form_draft = form_draft,
        created_at = now_utc()
      ),
      "suppose_regression_sensitivity_entry"
    ))
  )
  x$schema_version <- 13L
  validate_record(x)
  x
}

validate_regression_sensitivities <- function(x) {
  if (
    !is.null(x$regression_sensitivities) &&
      (x$schema_version < 13L || !is.list(x$regression_sensitivities))
  ) {
    abort_suppose("Invalid regression sensitivity collection.", "record")
  }
  for (e in x$regression_sensitivities) {
    check_seal(e, "suppose_regression_sensitivity_entry")
    check_seal(e$result, "suppose_regression_sensitivity")
    source <- research_regression(x, e$result$regression_id)
    if (
      !identical(e$result$record_id, x$record_id) ||
        !identical(e$result$fit_id, source$result$id) ||
        !identical(e$result$model, source$choice) ||
        !identical(e$result$observation_ids, source$result$spec$observation_ids)
    ) {
      abort_suppose("Regression sensitivity references disagree.", "reference")
    }
    if (
      !is.null(e$result$design_id) &&
        !identical(
          research_plan(x, e$result$design_id)$design$regression_id,
          source$id
        )
    ) {
      abort_suppose("Sensitivity design basis disagrees.", "reference")
    }
    if (!is.null(e$form_draft)) check_seal(e$form_draft, "suppose_form_draft")
  }
  invisible(x)
}
