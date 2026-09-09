#' Inspect sensitivity to prior strength and likelihood weight
#'
#' Recomputes the selected normal update under one-at-a-time power scaling of
#' the full joint prior or full likelihood. Prior power changes covariance to
#' `Sigma / alpha`; likelihood power weights the observed log likelihood by
#' `alpha`. Means, correlation, observations, support and fixed measurement SDs
#' remain specified by the original model. This does not test alternative shapes,
#' dependence structures or physical measurement SDs. Future measurement noise
#' remains unchanged when comparing predictions.
#'
#' Comparisons with retained prospective assessments are exploratory alternatives
#' to the frozen interval. They never revise a commitment or an assessment.
#' Only commitments based on this exact retained update are comparable; others
#' are explicitly listed as outside the selected basis. An incomplete or
#' inconclusive assessment never gains a numeric verdict through sensitivity.
#' @param x A record containing a retained analytic normal update.
#' @param update_id ID of the retained update entry to inspect.
#' @param powers Positive powers from 0.1 through 10, at most 21 values. Power 1
#'   is always included. The bounds limit this first workbench method.
#' @param components Components to vary separately: `prior`, `likelihood`, or both.
#' @param quantities Outputs to review: `estimate`, `probability`, `assessment`.
#'   The estimate is the mean difference; probability is above the claim threshold.
#' @param estimate_change Absolute mean-difference change worth reviewing, in
#'   outcome units. Must be positive; this is a user-selected review threshold.
#' @param probability_change Probability change worth reviewing, from 0 to 1
#'   excluding zero. This is an absolute probability difference, not a percent.
#' @return A sealed `suppose_sensitivity` with baseline, perturbations, failures,
#'   assessment comparisons and concrete follow-up questions. No global robustness
#'   certificate is produced.
#' @export
sensitivity_analysis <- function(
  x,
  update_id,
  powers = c(0.8, 1, 1.25),
  components = c("prior", "likelihood"),
  quantities = c("estimate", "probability", "assessment"),
  estimate_change = 1,
  probability_change = 0.05
) {
  validate_record(x)
  check_text(update_id, "update_id")
  u <- sensitivity_update(x, update_id)
  if (
    !is.numeric(powers) ||
      !length(powers) ||
      length(powers) > 21L ||
      !all(is.finite(powers)) ||
      any(powers < 0.1 | powers > 10)
  ) {
    abort_suppose("Supply at most 21 finite powers between 0.1 and 10.")
  }
  components <- sensitivity_choices(
    components,
    c("prior", "likelihood"),
    "components"
  )
  quantities <- sensitivity_choices(
    quantities,
    c("estimate", "probability", "assessment"),
    "quantities"
  )
  check_number(estimate_change, "estimate_change", 0)
  check_number(
    probability_change,
    "probability_change",
    0,
    1
  )
  if (estimate_change == 0 || probability_change == 0) {
    abort_suppose(
      "Choose positive changes worth reviewing for both quantities."
    )
  }
  powers <- sort(unique(c(1, powers)))
  p <- x$revisions[[u$revision]]$candidate
  evidence <- Filter(function(a) a$id %in% u$evidence_ids, x$observations)
  observations <- lapply(evidence, `[[`, "data")
  map <- unlist(u$result$condition_map, use.names = TRUE)
  baseline <- update_normal(
    p,
    observations,
    map,
    TRUE,
    u$result$diagnostics$level
  )
  if (!isTRUE(all.equal(baseline$target, u$result$target, tolerance = 1e-10))) {
    abort_suppose(
      "The retained update does not reproduce under this method; review the model before sensitivity analysis.",
      "computation"
    )
  }
  assessments <- if ("assessment" %in% quantities) x$assessments else list()
  rows <- list()
  for (component in components) {
    for (alpha in powers) {
      row <- tryCatch(
        {
          fit <- update_normal(
            p,
            observations,
            map,
            TRUE,
            u$result$diagnostics$level,
            prior_power = if (component == "prior") alpha else 1,
            likelihood_power = if (component == "likelihood") alpha else 1
          )
          covariance <- matrix(fit$posterior$covariance, 2)
          values <- c(unlist(fit$target), fit$posterior$means, covariance)
          if (
            !all(is.finite(values)) ||
              min(
                eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
              ) <
                -1e-8 * max(1, abs(covariance))
          ) {
            abort_suppose(
              "Non-finite or numerically invalid posterior covariance.",
              "computation"
            )
          }
          comparisons <- lapply(assessments, function(a) {
            sensitivity_assessment(
              a,
              find_test(x, a$commitment_id),
              u$id,
              fit,
              alpha == 1
            )
          })
          delta_mean <- fit$target$mean - baseline$target$mean
          delta_probability <- fit$target$probability_above -
            baseline$target$probability_above
          list(
            status = "completed",
            error = NULL,
            target = fit$target,
            estimate_change = delta_mean,
            probability_change = delta_probability,
            review_estimate = "estimate" %in%
              quantities &&
              abs(delta_mean) >= estimate_change,
            review_probability = "probability" %in%
              quantities &&
              abs(delta_probability) >= probability_change,
            review_assessment = any(vapply(
              comparisons,
              function(a) isTRUE(a$changed),
              logical(1)
            )),
            assessments = comparisons
          )
        },
        error = function(e) {
          list(
            status = "failed",
            error = cli::ansi_strip(conditionMessage(e)),
            target = NULL,
            estimate_change = NULL,
            probability_change = NULL,
            review_estimate = FALSE,
            review_probability = FALSE,
            review_assessment = FALSE,
            assessments = list()
          )
        }
      )
      row$component <- component
      row$power <- alpha
      rows[[length(rows) + 1L]] <- row
    }
  }
  followup <- sensitivity_followup(rows)
  seal(
    list(
      record_id = x$record_id,
      basis_id = proposal_basis_id(x),
      update_id = u$id,
      revision = u$revision,
      prior_id = p$id,
      claim_id = p$claim$id,
      evidence_ids = u$evidence_ids,
      assessment_ids = vapply(assessments, `[[`, character(1), "id"),
      units = p$claim$units,
      threshold = p$claim$threshold,
      baseline = baseline$target,
      baseline_diagnostics = baseline$diagnostics,
      powers = powers,
      components = components,
      quantities = quantities,
      estimate_threshold = estimate_change,
      probability_threshold = probability_change,
      rows = rows,
      followup = followup,
      scope = "One component at a time: full joint normal prior strength or full likelihood weight. Same means, correlation, support, observations and physical measurement SDs. No alternative prior shape, likelihood family, dependence model or global robustness claim.",
      settings = list(
        method = "analytic-normal-power-scaling-v1",
        r_version = as.character(getRversion())
      ),
      created_at = now_utc()
    ),
    "suppose_sensitivity"
  )
}

sensitivity_choices <- function(x, choices, name) {
  if (!is.character(x) || !length(x) || anyNA(x) || !all(x %in% choices)) {
    abort_suppose(
      "Choose supported {.arg {name}}: {paste(choices, collapse = ', ')}."
    )
  }
  unique(x)
}

sensitivity_update <- function(x, id) {
  matches <- Filter(function(u) identical(u$id, id), x$updates)
  if (length(matches) != 1L) {
    abort_suppose(
      "Select an exact retained update from this record.",
      "revision"
    )
  }
  matches[[1]]
}

sensitivity_assessment <- function(a, c, update_id, fit, original = FALSE) {
  out <- list(
    assessment_id = a$id,
    commitment_id = c$id,
    original_status = a$status,
    original_lower = c$prediction$lower,
    original_upper = c$prediction$upper,
    status = "not_comparable",
    reason = "The frozen prediction uses a different prior or update basis.",
    lower = NULL,
    upper = NULL,
    observed = NULL,
    changed = FALSE
  )
  if (!identical(c$update_id, update_id)) {
    return(out)
  }
  if (is.null(a$observed)) {
    out$status <- "no_numeric_assessment"
    out$reason <- "The retained assessment is waiting or inconclusive; no alternative numeric verdict is calculated."
    return(out)
  }
  sd <- sqrt(
    fit$target$sd^2 +
      sum(c$prediction$measurement_sd^2 / c$prediction$planned_n)
  )
  q <- stats::qnorm((1 + c$prediction$coverage) / 2)
  limits <- if (original) {
    c(c$prediction$lower, c$prediction$upper)
  } else {
    fit$target$mean + c(-1, 1) * q * sd
  }
  if (!all(is.finite(limits))) {
    abort_suppose(
      "The alternative prediction exceeded the numerical range.",
      "computation"
    )
  }
  out$status <- if (
    a$observed$difference >= limits[1] && a$observed$difference <= limits[2]
  ) {
    "within_prediction"
  } else {
    "outside_prediction"
  }
  out$reason <- "Exploratory alternative interval after seeing outcomes; the original commitment and assessment remain unchanged."
  out$lower <- limits[1]
  out$upper <- limits[2]
  out$observed <- a$observed$difference
  out$changed <- !identical(out$status, a$status)
  out
}

sensitivity_followup <- function(rows) {
  questions <- character()
  if (any(vapply(rows, function(r) r$status == "failed", logical(1)))) {
    questions <- c(
      questions,
      "Some perturbations failed. Review the failed powers and numerical scale before interpreting this range."
    )
  }
  for (component in c("prior", "likelihood")) {
    consequential <- any(vapply(
      rows,
      function(r) {
        identical(r$component, component) &&
          (r$review_estimate || r$review_probability || r$review_assessment)
      },
      logical(1)
    ))
    if (consequential) {
      questions <- c(
        questions,
        if (component == "prior") {
          "The selected review threshold is reached when prior strength changes. Which elicited interval or source justifies that strength, and should the prior be reviewed?"
        } else {
          "The selected review threshold is reached when likelihood weight changes. Are the independence and known measurement SD assumptions defensible, or is a different observation model needed?"
        }
      )
    }
  }
  if (!length(questions)) {
    questions <- "No selected review threshold was reached over the completed powers. Which alternative prior shape, measurement model or dependence assumption remains worth checking? This is not a robustness certificate."
  }
  questions
}

#' Retain a reviewed sensitivity analysis
#' @param x A local record.
#' @param sensitivity Result from [sensitivity_analysis()].
#' @param reason Why retain this comparison and its follow-up questions.
#' @param form_draft Optional original chat form suggestion, retained as provenance.
#' @return A record retaining the analysis separately from updates and assessments.
#' @export
record_sensitivity <- function(x, sensitivity, reason, form_draft = NULL) {
  validate_record(x)
  check_seal(sensitivity, "suppose_sensitivity")
  check_text(reason, "reason")
  if (!identical(sensitivity$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Recompute sensitivity before retaining it.",
      "stale"
    )
  }
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      !identical(form_draft$form, "sensitivity") ||
        !identical(form_draft$base_id, sensitivity$basis_id)
    ) {
      abort_suppose(
        "The form draft belongs to a different sensitivity basis.",
        "revision"
      )
    }
  }
  entry <- seal(
    list(
      result = sensitivity,
      reason = reason,
      form_draft = form_draft,
      created_at = now_utc()
    ),
    "suppose_sensitivity_entry"
  )
  x$sensitivities <- c(x$sensitivities, list(entry))
  x$schema_version <- max(x$schema_version, 8L)
  validate_record(x)
  x
}

validate_sensitivities <- function(x) {
  if (
    !is.null(x$sensitivities) &&
      (x$schema_version < 8 || !is.list(x$sensitivities))
  ) {
    abort_suppose("Invalid sensitivity collection.", "record")
  }
  for (entry in x$sensitivities) {
    check_seal(entry, "suppose_sensitivity_entry")
    s <- entry$result
    check_seal(s, "suppose_sensitivity")
    check_text(entry$reason, "sensitivity reason")
    if (!is.null(entry$form_draft)) {
      check_seal(entry$form_draft, "suppose_form_draft")
    }
    u <- sensitivity_update(x, s$update_id)
    if (
      !identical(s$record_id, x$record_id) ||
        !identical(s$prior_id, u$result$prior_id) ||
        !identical(s$claim_id, u$result$claim_id) ||
        s$revision != u$revision ||
        !setequal(s$evidence_ids, u$evidence_ids) ||
        !all(
          s$assessment_ids %in% vapply(x$assessments, `[[`, character(1), "id")
        )
    ) {
      abort_suppose(
        "Sensitivity references disagree with the retained record.",
        "revision"
      )
    }
  }
  invisible(x)
}
