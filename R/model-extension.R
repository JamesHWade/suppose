#' Compare the predictive implications of an added predictor
#'
#' Extends the current two-anchor normal prior with one shared additive normal
#' coefficient, independent of the anchor means. The scaled alternative measures
#' the predictor in meaningful changes, `(value - center) / scale`. The unscaled
#' alternative reuses the same numerical coefficient prior per raw unit, solely
#' to expose the consequences of that choice. Neither is fitted to observations.
#'
#' At other original-condition values, both comparisons use an explicitly new
#' linear interpolation/extrapolation assumption for the uncertain means. Known
#' measurement variance is linearly interpolated inside the anchors and held at
#' the nearest anchor outside. These are comparison assumptions, not previously
#' elicited beliefs. An additive common effect cancels from the original contrast
#' when the added predictor has the same value at both conditions.
#' @param x A record with a current normal prior.
#' @param predictor Name of the added predictor.
#' @param predictor_units Units of the added predictor; default generic `units`.
#' @param center Reference value where the added effect is zero.
#' @param scale A positive meaningful predictor change, in its stated units.
#' @param effect_mean,effect_sd Normal coefficient prior per meaningful change.
#'   The default mean is zero. The default SD is the root mean square of the
#'   original mean SDs: a visible starting assumption, not an elicited belief.
#' @param conditions Original-condition values to inspect. Defaults include the
#'   anchors, midpoint and points 25% of the anchor span outside each anchor.
#' @param predictor_values Added-predictor values; default `center + c(-1,0,1)*scale`.
#' @param plausible_lower,plausible_upper Optional bounds for plausible observed
#'   outcomes. Outside probabilities are descriptive flags, not model validation.
#' @return A sealed `suppose_extension_comparison` with aligned predictions,
#'   assumptions, defaults and references. No record changes automatically.
#' @export
compare_extension <- function(
  x,
  predictor,
  predictor_units = "units",
  center = 0,
  scale = 1,
  effect_mean = 0,
  effect_sd = NULL,
  conditions = NULL,
  predictor_values = NULL,
  plausible_lower = NULL,
  plausible_upper = NULL
) {
  validate_record(x)
  p <- utils::tail(x$revisions, 1)[[1]]$candidate
  if (is.null(p)) {
    abort_suppose(
      "Retain a normal prior before comparing an extension.",
      "incomplete"
    )
  }
  check_seal(p, "suppose_prior")
  check_text(predictor, "predictor")
  check_text(predictor_units, "predictor_units")
  check_number(center, "center")
  check_number(scale, "scale", 0)
  if (scale == 0) {
    abort_suppose("Choose a positive meaningful predictor change.")
  }
  check_number(effect_mean, "effect_mean")
  inherited_sd <- is.null(effect_sd)
  if (inherited_sd) {
    effect_sd <- sqrt(mean(p$mean_sd^2))
  }
  check_number(effect_sd, "effect_sd", 0)
  if (!is.null(plausible_lower)) {
    check_number(plausible_lower, "plausible_lower")
  }
  if (!is.null(plausible_upper)) {
    check_number(plausible_upper, "plausible_upper")
  }
  if (
    !is.null(plausible_lower) &&
      !is.null(plausible_upper) &&
      plausible_lower >= plausible_upper
  ) {
    abort_suppose("The lower plausible bound must be below the upper bound.")
  }
  if (is.null(conditions)) {
    conditions <- p$conditions[1] +
      diff(p$conditions) * c(-0.25, 0, 0.5, 1, 1.25)
  }
  if (is.null(predictor_values)) {
    predictor_values <- center + c(-1, 0, 1) * scale
  }
  for (name in c("conditions", "predictor_values")) {
    values <- get(name)
    if (
      !is.numeric(values) ||
        !length(values) ||
        length(values) > 21L ||
        !all(is.finite(values))
    ) {
      abort_suppose("Supply 1 to 21 finite values for {.arg {name}}.")
    }
  }
  conditions <- sort(unique(conditions))
  predictor_values <- sort(unique(predictor_values))
  sigma <- outer(p$mean_sd, p$mean_sd) *
    matrix(c(1, p$correlation, p$correlation, 1), 2)
  rows <- list()
  for (condition in conditions) {
    for (value in predictor_values) {
      t <- (condition - p$conditions[1]) / diff(p$conditions)
      w <- c(1 - t, t)
      mu <- sum(w * p$means)
      variance <- max(0, drop(w %*% sigma %*% w))
      noise <- sum(c(1 - min(1, max(0, t)), min(1, max(0, t))) * p$batch_sd^2)
      for (model in c("original", "unscaled", "scaled")) {
        z <- switch(
          model,
          original = 0,
          unscaled = value - center,
          scaled = (value - center) / scale
        )
        mean <- mu + effect_mean * z
        mean_variance <- variance + (effect_sd * z)^2
        outcome_variance <- mean_variance + noise
        if (
          !all(is.finite(c(mean, mean_variance, outcome_variance))) ||
            mean_variance < 0 ||
            outcome_variance < 0
        ) {
          abort_suppose(
            "This comparison exceeds the numerical range. Review the units and scales; no extension was retained.",
            "computation"
          )
        }
        sd <- sqrt(outcome_variance)
        outside <- NULL
        if (!is.null(plausible_lower) || !is.null(plausible_upper)) {
          outside <- if (sd == 0) {
            as.numeric(
              (!is.null(plausible_lower) && mean < plausible_lower) ||
                (!is.null(plausible_upper) && mean > plausible_upper)
            )
          } else {
            (if (is.null(plausible_lower)) {
              0
            } else {
              stats::pnorm(plausible_lower, mean, sd)
            }) +
              (if (is.null(plausible_upper)) {
                0
              } else {
                stats::pnorm(plausible_upper, mean, sd, lower.tail = FALSE)
              })
          }
        }
        rows[[length(rows) + 1L]] <- list(
          model = model,
          condition = condition,
          predictor_value = value,
          mean = mean,
          mean_sd = sqrt(mean_variance),
          outcome_sd = sd,
          mean_lower = mean - stats::qnorm(0.95) * sqrt(mean_variance),
          mean_upper = mean + stats::qnorm(0.95) * sqrt(mean_variance),
          outcome_lower = mean - stats::qnorm(0.95) * sd,
          outcome_upper = mean + stats::qnorm(0.95) * sd,
          outside_probability = outside,
          condition_basis = if (condition %in% p$conditions) {
            "elicited anchor"
          } else if (t < 0 || t > 1) {
            "assumed extrapolation"
          } else {
            "assumed interpolation"
          }
        )
      }
    }
  }
  numeric_rows <- unlist(lapply(rows, function(r) {
    unlist(r[c("mean_lower", "mean_upper", "outcome_lower", "outcome_upper")])
  }))
  if (!all(is.finite(numeric_rows))) {
    abort_suppose(
      "Prediction intervals exceed the numerical range.",
      "computation"
    )
  }
  seal(
    list(
      record_id = x$record_id,
      basis_id = proposal_basis_id(x),
      revision = length(x$revisions),
      prior_id = p$id,
      claim_id = p$claim$id,
      units = p$claim$units,
      condition_units = p$condition_units,
      anchors = p$conditions,
      settings = list(
        predictor = predictor,
        predictor_units = predictor_units,
        center = center,
        scale = scale,
        effect_mean = effect_mean,
        effect_sd = effect_sd,
        conditions = conditions,
        predictor_values = predictor_values,
        plausible_lower = plausible_lower,
        plausible_upper = plausible_upper
      ),
      defaults = list(
        effect_sd = if (inherited_sd) {
          "Starting suggestion: root mean square of original mean SDs"
        } else {
          "Supplied for review"
        }
      ),
      rows = rows,
      matched_contrast = list(
        mean = unname(diff(p$means)),
        sd = sqrt(max(0, sum(diag(sigma)) - 2 * sigma[1, 2])),
        explanation = "At the same added-predictor value, the common additive effect cancels from the original high-minus-low mean contrast. An interaction or dependence assumption would require a different model."
      ),
      assumptions = c(
        "One shared additive normal coefficient, independent of the original jointly normal anchor means; no interaction.",
        "The same original condition and added-predictor value are compared in all three alternatives.",
        "Straight-line mean interpolation/extrapolation is a new comparison assumption; only the original anchors were elicited.",
        "Original known measurement variances interpolate between anchors and use the nearest anchor outside; no measurement SD is fitted.",
        "Defaults are starting suggestions. Predictive consistency does not establish mechanistic equivalence, causality or model adequacy."
      ),
      method = "normal-one-additive-predictor-v1",
      created_at = now_utc()
    ),
    "suppose_extension_comparison"
  )
}

#' Retain a reviewed model extension alongside the original model
#' @param x A record.
#' @param comparison A result from [compare_extension()].
#' @param author Person reviewing the model implications.
#' @param reason Scientific reason for the extension and selected assumptions.
#' @param choice The `scaled` or `unscaled` coefficient prior to retain.
#' @param reviewed Explicit confirmation that the assumptions and predictions
#'   were reviewed. This is not empirical validation.
#' @param form_draft Optional chat form draft supplying initial suggestions.
#' @return A record with a reviewed model alternative. Original models, updates
#'   and tests remain intact. The normal-update/test APIs do not automatically
#'   switch to this extension; fitting extended models is not implemented.
#' @export
record_extension <- function(
  x,
  comparison,
  author,
  reason,
  choice = "scaled",
  reviewed = FALSE,
  form_draft = NULL
) {
  validate_record(x)
  check_seal(comparison, "suppose_extension_comparison")
  check_text(author, "author")
  check_text(reason, "reason")
  if (!isTRUE(reviewed)) {
    abort_suppose(
      "Review the new assumptions and predictions before retaining the extension."
    )
  }
  if (
    !is.character(choice) ||
      length(choice) != 1L ||
      !choice %in% c("scaled", "unscaled")
  ) {
    abort_suppose("Choose the scaled or unscaled extension.")
  }
  if (!identical(comparison$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Preview the extension again before retaining it.",
      "stale"
    )
  }
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      !identical(form_draft$form, "extension") ||
        !identical(form_draft$base_id, comparison$basis_id)
    ) {
      abort_suppose(
        "The form draft belongs to a different comparison basis.",
        "revision"
      )
    }
  }
  entry <- seal(
    list(
      comparison = comparison,
      choice = choice,
      author = author,
      reason = reason,
      status = "reviewed model alternative",
      form_draft = form_draft,
      created_at = now_utc()
    ),
    "suppose_model_extension"
  )
  x$model_extensions <- c(x$model_extensions, list(entry))
  x$schema_version <- max(x$schema_version, 9L)
  validate_record(x)
  x
}

validate_extensions <- function(x) {
  if (
    !is.null(x$model_extensions) &&
      (x$schema_version < 9 || !is.list(x$model_extensions))
  ) {
    abort_suppose("Invalid model extension collection.", "record")
  }
  for (entry in x$model_extensions) {
    check_seal(entry, "suppose_model_extension")
    c <- entry$comparison
    check_seal(c, "suppose_extension_comparison")
    check_count(c$revision, "extension revision", upper = length(x$revisions))
    p <- x$revisions[[c$revision]]$candidate
    if (
      !identical(c$record_id, x$record_id) ||
        !identical(c$prior_id, p$id) ||
        !identical(c$claim_id, p$claim$id)
    ) {
      abort_suppose(
        "Model extension references disagree with the record.",
        "revision"
      )
    }
    if (!is.null(entry$form_draft)) {
      check_seal(entry$form_draft, "suppose_form_draft")
    }
  }
  invisible(x)
}
