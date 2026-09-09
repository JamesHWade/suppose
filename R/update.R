#' Update a normal prior using designated measurements
#'
#' Conditions independent normal measurements on the existing two-mean normal
#' prior using an analytic Gaussian update. Measurement standard deviations are
#' treated as known, must be positive, and are not estimated from these outcomes.
#' Singular prior correlations are supported. This is retrospective inference,
#' not a prospective test or unconditional proof of the claim.
#'
#' Missing outcomes are excluded with their IDs retained. Repeated specimens
#' are rejected because this model cannot represent their dependence. The caller
#' must explicitly confirm that the retained measurement units are independent.
#' @param x A fitted `suppose_prior`.
#' @param observations One `suppose_observations` object, or a list of them.
#'   All must be designated for updating with known, non-prior exposure.
#' @param condition_map Named numeric vector mapping the two observation labels
#'   to the prior's two condition values, for example `c(control = 140, treated = 160)`.
#' @param independent Explicit confirmation of independent measurement units.
#' @param diagnostic_level Tail-area threshold for flagged model checks.
#' @return A sealed `suppose_update` retaining analytic posterior parameters,
#'   target summaries, predictive summaries, input references, and diagnostics.
#' @export
update_prior <- function(
  x,
  observations,
  condition_map,
  independent = FALSE,
  diagnostic_level = 0.01
) {
  update_normal(x, observations, condition_map, independent, diagnostic_level)
}

update_normal <- function(
  x,
  observations,
  condition_map,
  independent = FALSE,
  diagnostic_level = 0.01,
  prior_power = 1,
  likelihood_power = 1
) {
  rlang::local_error_call(rlang::caller_env())
  check_seal(x, "suppose_prior")
  if (!isTRUE(independent)) {
    abort_suppose(
      "Confirm independent measurement units explicitly; paired or clustered measurements need a different likelihood.",
      "independence"
    )
  }
  if (any(x$batch_sd <= 0)) {
    abort_suppose(
      "This update method requires positive known measurement standard deviations.",
      "unsupported"
    )
  }
  check_number(diagnostic_level, "diagnostic_level", 0, 1)
  if (diagnostic_level == 0 || diagnostic_level == 1) {
    abort_suppose(
      "Choose a diagnostic tail-area threshold strictly between zero and one."
    )
  }
  if (
    inherits(observations, "suppose_observations") ||
      identical(observations$type, "suppose_observations")
  ) {
    observations <- list(observations)
  }
  if (!is.list(observations) || !length(observations)) {
    abort_suppose("Supply designated observations.")
  }
  if (
    !is.numeric(condition_map) ||
      length(condition_map) != 2L ||
      is.null(names(condition_map)) ||
      anyDuplicated(names(condition_map)) ||
      !setequal(unname(condition_map), x$conditions)
  ) {
    abort_suppose(
      "Map two distinct observation labels to the prior's exact condition values.",
      "condition"
    )
  }
  check_strings(names(condition_map), "condition labels")
  rows <- list()
  keys <- character()
  specimens <- character()
  for (o in observations) {
    validate_observations(o)
    if (o$role != "update" || !o$exposure %in% c("unseen", "explored")) {
      abort_suppose(
        "Use only observations designated for updating; unknown exposure or evidence already used in the prior cannot be reused.",
        "exposure"
      )
    }
    if (!identical(o$target_units, x$claim$units)) {
      abort_suppose(
        "Observation units must match the prior's outcome units.",
        "units"
      )
    }
    for (row in o$rows) {
      if (!row$condition %in% names(condition_map)) {
        abort_suppose(
          "An observation condition is absent from the explicit mapping.",
          "condition"
        )
      }
      key <- object_id(list(o$source, row$observation_id))
      if (key %in% keys) {
        abort_suppose(
          "The same source/observation ID was supplied more than once.",
          "duplicate"
        )
      }
      keys <- c(keys, key)
      specimen <- object_id(list(o$source, row$batch, row$specimen))
      if (!is.null(row$converted) && specimen %in% specimens) {
        abort_suppose(
          "Repeated specimens cannot be treated as independent measurements by this model.",
          "independence"
        )
      }
      if (!is.null(row$converted)) {
        specimens <- c(specimens, specimen)
      }
      rows[[length(rows) + 1L]] <- list(
        source = o$source,
        id = row$observation_id,
        group = match(unname(condition_map[[row$condition]]), x$conditions),
        value = row$converted
      )
    }
  }
  usable <- Filter(function(row) !is.null(row$value), rows)
  if (!length(usable)) {
    abort_suppose(
      "No observed outcomes remain after excluding missing values.",
      "incomplete"
    )
  }
  means <- x$means
  covariance <- outer(x$mean_sd, x$mean_sd) *
    matrix(c(1, x$correlation, x$correlation, 1), 2) /
    prior_power
  prior_covariance <- covariance
  groups <- lapply(seq_len(2), function(i) {
    values <- vapply(
      Filter(function(row) row$group == i, usable),
      `[[`,
      numeric(1),
      "value"
    )
    list(
      n = length(values),
      mean = if (length(values)) mean(values) else NULL,
      residual_ss = if (length(values)) sum((values - mean(values))^2) else 0
    )
  })
  if (!all(is.finite(vapply(groups, `[[`, numeric(1), "residual_ss")))) {
    abort_suppose(
      "The measurements exceed the numerical range of this update; no result was retained.",
      "computation"
    )
  }
  conflict <- 0
  df <- 0L
  for (i in seq_len(2)) {
    g <- groups[[i]]
    if (!g$n) {
      next
    }
    noise <- x$batch_sd[i]^2 / g$n / likelihood_power
    total <- covariance[i, i] + noise
    residual <- g$mean - means[i]
    conflict <- conflict + residual^2 / total
    df <- df + 1L
    gain <- covariance[, i] / total
    means <- means + gain * residual
    a <- diag(2)
    a[, i] <- a[, i] - gain
    # Joseph form preserves positive semidefiniteness without inverting the prior.
    covariance <- a %*% covariance %*% t(a) + tcrossprod(gain) * noise
    covariance <- (covariance + t(covariance)) / 2
  }
  if (!all(is.finite(c(means, covariance, conflict)))) {
    abort_suppose(
      "The analytic update produced non-finite values; no result was retained.",
      "computation"
    )
  }
  marginal <- function(mu, sigma) {
    delta <- diff(mu)
    sd <- sqrt(max(0, sum(diag(sigma)) - 2 * sigma[1, 2]))
    list(
      mean = unname(delta),
      sd = sd,
      lower = unname(delta - stats::qnorm(0.95) * sd),
      upper = unname(delta + stats::qnorm(0.95) * sd),
      probability_above = if (sd == 0) {
        as.numeric(delta > x$claim$threshold)
      } else {
        stats::pnorm(x$claim$threshold, delta, sd, lower.tail = FALSE)
      }
    )
  }
  variance_checks <- lapply(seq_len(2), function(i) {
    g <- groups[[i]]
    if (g$n < 2L) {
      return(list(
        condition = x$conditions[i],
        status = "insufficient_data",
        n = g$n
      ))
    }
    statistic <- g$residual_ss / x$batch_sd[i]^2
    tail_area <- min(
      1,
      2 *
        min(
          stats::pchisq(statistic, g$n - 1),
          stats::pchisq(statistic, g$n - 1, lower.tail = FALSE)
        )
    )
    list(
      condition = x$conditions[i],
      n = g$n,
      statistic = statistic,
      df = g$n - 1L,
      tail_area = tail_area,
      status = if (tail_area < diagnostic_level) {
        "model_mismatch"
      } else {
        "not_flagged"
      }
    )
  })
  conflict_tail <- stats::pchisq(conflict, df, lower.tail = FALSE)
  predictive_covariance <- covariance + diag(x$batch_sd^2)
  seal(
    list(
      prior_id = x$id,
      claim_id = x$claim$id,
      observation_ids = vapply(observations, `[[`, character(1), "id"),
      condition_map = as.list(condition_map),
      independent = TRUE,
      conditions = x$conditions,
      units = x$claim$units,
      threshold = x$claim$threshold,
      posterior = list(
        means = unname(means),
        covariance = as.numeric(covariance)
      ),
      prior = marginal(x$means, prior_covariance),
      target = marginal(means, covariance),
      predictive = marginal(means, predictive_covariance),
      groups = groups,
      excluded = Filter(function(row) is.null(row$value), rows),
      diagnostics = list(
        computation = "completed",
        method = "analytic Gaussian conditioning; no sampling diagnostics required",
        level = diagnostic_level,
        prior_predictive_conflict = list(
          statistic = conflict,
          df = df,
          tail_area = conflict_tail,
          status = if (conflict_tail < diagnostic_level) {
            "prior_data_conflict"
          } else {
            "not_flagged"
          }
        ),
        measurement_variation = variance_checks,
        interpretation = "Tail areas are model checks, not probabilities that the model is true. Not flagged does not establish adequate fit; small samples have limited diagnostic power."
      ),
      settings = list(
        method = "normal-known-variance-v1",
        r_version = as.character(getRversion())
      ),
      created_at = now_utc()
    ),
    "suppose_update"
  )
}

#' Retain a fitted update without replacing its prior
#' @param x A local record.
#' @param update A result from [update_prior()].
#' @param reason Why this analysis was performed.
#' @return A record with a separate, attributable update collection.
#' @export
record_update <- function(x, update, reason) {
  validate_record(x)
  check_seal(update, "suppose_update")
  check_text(reason, "reason")
  i <- length(x$revisions)
  e <- x$revisions[[i]]
  if (
    !identical(update$prior_id, e$candidate$id) ||
      !identical(update$claim_id, e$claim$id)
  ) {
    abort_suppose(
      "The update must reference the current claim and prior.",
      "revision"
    )
  }
  evidence <- Filter(
    function(a) a$data$id %in% update$observation_ids && a$revision == i,
    x$observations
  )
  if (
    !setequal(
      vapply(evidence, function(a) a$data$id, character(1)),
      update$observation_ids
    )
  ) {
    abort_suppose(
      "Attach the update's exact observations to this revision first.",
      "revision"
    )
  }
  attachment <- seal(
    list(
      result = update,
      revision = i,
      evidence_ids = vapply(evidence, `[[`, character(1), "id"),
      reason = reason,
      created_at = now_utc()
    ),
    "suppose_update_entry"
  )
  if (
    any(vapply(
      x$updates,
      function(a) identical(a$result$id, update$id),
      logical(1)
    ))
  ) {
    abort_suppose("This update is already retained.", "duplicate")
  }
  x$updates <- c(x$updates, list(attachment))
  x$schema_version <- max(x$schema_version, 5L)
  validate_record(x)
  x
}

validate_updates <- function(x) {
  for (a in x$updates) {
    check_seal(a, "suppose_update_entry")
    check_seal(a$result, "suppose_update")
    check_count(a$revision, "update revision", upper = length(x$revisions))
    e <- x$revisions[[a$revision]]
    if (
      !identical(e$candidate$id, a$result$prior_id) ||
        !identical(e$claim$id, a$result$claim_id)
    ) {
      abort_suppose(
        "Update references disagree with the record revision.",
        "revision"
      )
    }
    evidence <- Filter(
      function(o) o$id %in% a$evidence_ids && o$revision == a$revision,
      x$observations
    )
    if (!setequal(vapply(evidence, `[[`, character(1), "id"), a$evidence_ids)) {
      abort_suppose("Update evidence references are missing.", "revision")
    }
    if (
      !setequal(
        vapply(evidence, function(o) o$data$id, character(1)),
        a$result$observation_ids
      )
    ) {
      abort_suppose("Update observation references disagree.", "revision")
    }
    check_text(a$reason, "update reason")
  }
  invisible(x)
}

#' @export
print.suppose_update <- function(x, ...) {
  check_seal(x, "suppose_update")
  cli::cli_h2("Beliefs updated under the stated model")
  cli::cli_text(
    "Mean difference: {round(x$target$mean, 3)} {x$units}; central 90% interval {round(x$target$lower, 3)} to {round(x$target$upper, 3)}."
  )
  cli::cli_text(
    "P(difference > {x$threshold} {x$units}) = {round(x$target$probability_above, 3)}. Conditional on the prior, measurements, and likelihood assumptions."
  )
  cli::cli_text(
    "Prior predictive check: {x$diagnostics$prior_predictive_conflict$status}."
  )
  invisible(x)
}
