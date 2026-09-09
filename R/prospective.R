#' Freeze a prediction before collecting designated outcomes
#'
#' The first method checks the difference between two future sample means against
#' a central normal prediction interval. Measurement IDs and conditions are fixed
#' in advance; all planned measurements are required. Collection must occur after
#' commitment and no later than the horizon. There is no partial-data comparison,
#' imputation, or optional stopping rule. A declaration of unseen outcomes and a
#' timestamp do not independently establish lack of exposure or protocol validity.
#'
#' The basis is the current prior, or an explicitly selected retained update of
#' that prior. Known measurement SDs must be positive. Existing revisions and
#' commitments are never changed. To change a plan, create a new commitment while
#' its designated outcomes remain unexamined and identify the plan it replaces.
#' @param x An elicitation record with a current numerical prior.
#' @param planned A data frame with exactly `observation_id` and `condition`
#'   character columns. IDs must be unique within the committed source.
#' @param condition_map Named numeric vector mapping the two condition labels to
#'   the prior's condition values, for example `c(control = 0, treated = 1)`.
#' @param source Stable identifier for the designated future dataset.
#' @param protocol Exact protocol identifier to use when importing measurements.
#' @param horizon Collection deadline as a UTC ISO 8601 timestamp.
#' @param author Person making the commitment.
#' @param reason Why this test is informative.
#' @param design `"observational"` or `"intervention"`.
#' @param design_details Sampling or assignment procedure and its limitations.
#' @param independent Explicit declaration of independent measurement units.
#' @param outcomes_unseen Explicit declaration that the designated outcomes have
#'   not been examined. Known existing measurements cannot be designated again.
#' @param coverage Central predictive probability, between zero and one.
#' @param update_id Optional retained update-entry ID; `NULL` uses the prior.
#' @param replaces Optional ID of an earlier commitment in this record.
#' @return A record with a sealed `suppose_test_commitment` in `commitments`.
#' @export
commit_test <- function(
  x,
  planned,
  condition_map,
  source,
  protocol,
  horizon,
  author,
  reason,
  design = c("observational", "intervention"),
  design_details,
  independent = FALSE,
  outcomes_unseen = FALSE,
  coverage = 0.9,
  update_id = NULL,
  replaces = NULL
) {
  validate_record(x)
  for (nm in c(
    "source",
    "protocol",
    "horizon",
    "author",
    "reason",
    "design_details"
  )) {
    check_text(get(nm), nm)
  }
  design <- match.arg(design)
  if (!isTRUE(independent) || !isTRUE(outcomes_unseen)) {
    abort_suppose(
      "Explicitly confirm independent units and unexamined designated outcomes before committing.",
      "commitment"
    )
  }
  created_at <- now_utc()
  if (
    test_time(horizon, "horizon") <= test_time(created_at, "commitment time")
  ) {
    abort_suppose(
      "The collection deadline must be in the future when the commitment is frozen.",
      "horizon"
    )
  }
  entry <- utils::tail(x$revisions, 1)[[1]]
  p <- entry$candidate
  if (is.null(p)) {
    abort_suppose(
      "Retain a numerical prior before committing this kind of test.",
      "unsupported"
    )
  }
  if (any(p$batch_sd <= 0)) {
    abort_suppose(
      "This test requires positive known measurement SDs.",
      "unsupported"
    )
  }
  plan <- test_plan(planned, condition_map, p$conditions)
  existing <- unlist(lapply(
    Filter(function(a) identical(a$data$source, source), x$observations),
    function(a) vapply(a$data$rows, `[[`, character(1), "observation_id")
  ))
  if (any(planned$observation_id %in% existing)) {
    abort_suppose(
      "Planned measurement IDs are already present in this record. Use new outcomes; existing evidence cannot become a prospective test.",
      "exposure"
    )
  }
  if (
    !is.null(replaces) &&
      !replaces %in% vapply(x$commitments, `[[`, character(1), "id")
  ) {
    abort_suppose("The replaced commitment is not in this record.", "revision")
  }
  basis <- test_basis(x, update_id)
  prediction <- test_prediction(basis, plan, coverage, p)
  commitment <- seal(
    list(
      record_id = x$record_id,
      revision = length(x$revisions),
      claim_id = entry$claim$id,
      prior_id = p$id,
      update_id = update_id,
      basis_observation_ids = basis$observation_ids,
      context_observation_ids = vapply(
        x$observations,
        function(a) a$data$id,
        character(1)
      ),
      source = source,
      protocol = protocol,
      planned = plan,
      condition_map = as.list(condition_map),
      prediction = prediction,
      design = design,
      design_details = design_details,
      independent = TRUE,
      outcomes_unseen = TRUE,
      author = author,
      reason = reason,
      created_at = created_at,
      horizon = horizon,
      replaces = replaces,
      rule = list(
        method = "normal-planned-mean-difference-v1",
        completion = "all_planned_outcomes_or_deadline",
        comparison = "inclusive_central_prediction_interval",
        missing = "no_imputation_or_partial_comparison",
        selection = "exact_source_and_planned_ids",
        conversion = "identity_in_model_units"
      )
    ),
    "suppose_test_commitment"
  )
  x$commitments <- c(x$commitments, list(commitment))
  x$schema_version <- max(x$schema_version, 7L)
  validate_record(x)
  x
}

#' Assess designated outcomes against their original frozen prediction
#'
#' Selects all attached measurements with the committed source and planned IDs,
#' including attachments made after later claim revisions. It never changes the
#' commitment or refits a model. Measurements must be designated for assessment,
#' declared unseen in their provenance, and use the committed protocol and units
#' without conversion. Unknown, pre-commitment, future-dated, or out-of-window
#' observation times prevent a numerical comparison.
#'
#' An incomplete cohort before its deadline is `awaiting_outcomes`; after the
#' deadline it is `inconclusive`. A complete, eligible cohort is compared with the
#' frozen interval only after protocol adherence is explicitly confirmed. Results
#' are `within_prediction` or `outside_prediction`, not claims of truth, causality,
#' or global model adequacy. Later evidence creates another assessment, retaining
#' the earlier result. Repeating an unchanged assessment is rejected.
#' @param x An elicitation record.
#' @param commitment_id ID of the original frozen commitment.
#' @param author Person reviewing the assessment.
#' @param reason Why this assessment is being recorded.
#' @param protocol_followed Explicit confirmation that collection followed the
#'   documented protocol, including independent measurement units.
#' @return A record with a sealed `suppose_test_assessment` in `assessments`.
#' @export
assess_test <- function(
  x,
  commitment_id,
  author,
  reason,
  protocol_followed = FALSE
) {
  validate_record(x)
  for (nm in c("commitment_id", "author", "reason")) {
    check_text(get(nm), nm)
  }
  if (
    !is.logical(protocol_followed) ||
      length(protocol_followed) != 1L ||
      is.na(protocol_followed)
  ) {
    abort_suppose(
      "Protocol adherence must be explicitly TRUE or FALSE.",
      "assessment"
    )
  }
  commitment <- find_test(x, commitment_id)
  result <- evaluate_test(x, commitment, protocol_followed, now_utc())
  previous <- Filter(
    function(a) identical(a$commitment_id, commitment_id),
    x$assessments
  )
  signature <- test_assessment_signature(result)
  if (
    length(previous) &&
      identical(
        test_assessment_signature(utils::tail(previous, 1)[[1]]),
        signature
      )
  ) {
    abort_suppose(
      "This assessment is already retained for the same evidence and outcome. Add later outcomes or wait for the deadline before reassessing.",
      "duplicate"
    )
  }
  result$author <- author
  result$reason <- reason
  result$supersedes <- if (length(previous)) {
    utils::tail(previous, 1)[[1]]$id
  } else {
    NULL
  }
  x$assessments <- c(
    x$assessments,
    list(seal(result, "suppose_test_assessment"))
  )
  x$schema_version <- max(x$schema_version, 7L)
  validate_record(x)
  x
}

# Strict UTC parsing also rejects normalized invalid dates such as February 30.
test_time <- function(x, name) {
  check_text(x, name)
  parsed <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (
    !grepl(
      "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$",
      x
    ) ||
      is.na(parsed) ||
      format(parsed, "%Y-%m-%dT%H:%M:%S", tz = "UTC") != substr(x, 1, 19)
  ) {
    abort_suppose(
      "{.arg {name}} must be a valid UTC timestamp, such as 2026-09-08T12:00:00Z.",
      "time",
      name = name
    )
  }
  as.numeric(parsed)
}

test_plan <- function(planned, condition_map, conditions) {
  if (
    !is.data.frame(planned) ||
      !setequal(names(planned), c("observation_id", "condition"))
  ) {
    abort_suppose(
      "Supply planned observation_id and condition columns.",
      "commitment"
    )
  }
  check_count(nrow(planned), "planned measurements", 2, 10000)
  for (nm in names(planned)) {
    check_strings(planned[[nm]], nm)
  }
  if (anyDuplicated(planned$observation_id)) {
    abort_suppose("Planned measurement IDs must be unique.", "duplicate")
  }
  if (
    !is.numeric(condition_map) ||
      length(condition_map) != 2L ||
      is.null(names(condition_map)) ||
      anyDuplicated(names(condition_map)) ||
      !setequal(unname(condition_map), conditions)
  ) {
    abort_suppose(
      "Map two distinct labels to the prior's exact conditions.",
      "condition"
    )
  }
  check_strings(names(condition_map), "condition labels")
  if (!setequal(unique(planned$condition), names(condition_map))) {
    abort_suppose(
      "Plan at least one measurement in each mapped condition, with no other labels.",
      "condition"
    )
  }
  lapply(seq_len(nrow(planned)), function(i) {
    list(
      observation_id = planned$observation_id[i],
      condition = planned$condition[i],
      group = match(unname(condition_map[[planned$condition[i]]]), conditions)
    )
  })
}

test_basis <- function(x, update_id) {
  p <- utils::tail(x$revisions, 1)[[1]]$candidate
  if (is.null(update_id)) {
    return(list(
      means = p$means,
      covariance = outer(p$mean_sd, p$mean_sd) *
        matrix(c(1, p$correlation, p$correlation, 1), 2),
      observation_ids = character()
    ))
  }
  check_text(update_id, "update_id")
  selected <- Filter(
    function(a) identical(a$id, update_id) && a$revision == length(x$revisions),
    x$updates
  )
  if (length(selected) != 1L) {
    abort_suppose("Select an update of the current retained prior.", "revision")
  }
  u <- selected[[1]]$result
  list(
    means = u$posterior$means,
    covariance = matrix(u$posterior$covariance, 2),
    observation_ids = u$observation_ids
  )
}

test_prediction <- function(basis, plan, coverage, prior) {
  check_number(coverage, "coverage", 0, 1)
  if (coverage == 0 || coverage == 1) {
    abort_suppose(
      "Predictive coverage must lie strictly between zero and one.",
      "commitment"
    )
  }
  n <- vapply(
    1:2,
    function(g) sum(vapply(plan, function(row) row$group == g, logical(1))),
    integer(1)
  )
  covariance <- basis$covariance
  variance <- max(0, sum(diag(covariance)) - 2 * covariance[1, 2]) +
    sum(prior$batch_sd^2 / n)
  mu <- unname(diff(basis$means))
  sd <- sqrt(variance)
  z <- stats::qnorm((1 + coverage) / 2)
  limits <- mu + c(-1, 1) * z * sd
  if (!all(is.finite(c(mu, sd, limits))) || sd <= 0) {
    abort_suppose(
      "The planned prediction exceeds the supported numerical range.",
      "computation"
    )
  }
  list(
    mean = mu,
    sd = sd,
    lower = limits[1],
    upper = limits[2],
    coverage = coverage,
    planned_n = n,
    measurement_sd = prior$batch_sd,
    basis_means = basis$means,
    basis_covariance = as.numeric(covariance),
    units = prior$claim$units,
    conditions = prior$conditions,
    condition_units = prior$condition_units
  )
}

find_test <- function(x, id) {
  found <- Filter(function(a) identical(a$id, id), x$commitments)
  if (length(found) != 1L) {
    abort_suppose("Select a commitment from this record.", "commitment")
  }
  found[[1]]
}

test_assessment_signature <- function(a) {
  object_id(a[c(
    "commitment_id",
    "evidence_ids",
    "observation_ids",
    "status",
    "issues",
    "missing_ids",
    "excluded_ids",
    "observed",
    "protocol_followed"
  )])
}

evaluate_test <- function(x, commitment, protocol_followed, assessed_at) {
  ids <- vapply(commitment$planned, `[[`, character(1), "observation_id")
  observations <- list()
  evidence_ids <- observation_ids <- excluded <- issues <- character()
  for (a in x$observations) {
    d <- a$data
    if (!identical(d$source, commitment$source)) {
      next
    }
    relevant <- Filter(function(row) row$observation_id %in% ids, d$rows)
    excluded <- c(
      excluded,
      vapply(
        Filter(function(row) !row$observation_id %in% ids, d$rows),
        `[[`,
        character(1),
        "observation_id"
      )
    )
    if (!length(relevant)) {
      next
    }
    evidence_ids <- c(evidence_ids, a$id)
    observation_ids <- c(observation_ids, d$id)
    if (d$role != "assessment" || d$exposure != "unseen") {
      issues <- c(issues, "ineligible_evidence_exposure")
    }
    if (!identical(d$protocol, commitment$protocol)) {
      issues <- c(issues, "protocol_identifier_mismatch")
    }
    if (
      !identical(d$units, commitment$prediction$units) ||
        !identical(d$target_units, commitment$prediction$units) ||
        d$conversion$scale != 1 ||
        d$conversion$offset != 0
    ) {
      issues <- c(issues, "units_or_conversion_mismatch")
    }
    if (
      test_time(d$created_at, "import time") <
        test_time(commitment$created_at, "commitment time")
    ) {
      issues <- c(issues, "evidence_imported_before_commitment")
    }
    observations <- c(observations, relevant)
  }
  missing <- character()
  values <- list(numeric(), numeric())
  specimens <- character()
  for (plan in commitment$planned) {
    row <- Filter(
      function(row) identical(row$observation_id, plan$observation_id),
      observations
    )
    if (!length(row) || is.null(row[[1]]$converted)) {
      missing <- c(missing, plan$observation_id)
      next
    }
    row <- row[[1]]
    if (!identical(row$condition, plan$condition)) {
      issues <- c(issues, "condition_mismatch")
    }
    if (identical(row$observed_at, "unknown")) {
      issues <- c(issues, "unknown_observation_time")
    } else {
      time <- test_time(row$observed_at, "observation time")
      if (time <= test_time(commitment$created_at, "commitment time")) {
        issues <- c(issues, "outcome_before_or_at_commitment")
      }
      if (time > test_time(commitment$horizon, "horizon")) {
        issues <- c(issues, "outcome_after_deadline")
      }
      if (time > test_time(assessed_at, "assessment time")) {
        issues <- c(issues, "future_dated_outcome")
      }
    }
    specimen <- object_id(list(row$batch, row$specimen))
    if (specimen %in% specimens) {
      issues <- c(issues, "repeated_measurement_unit")
    }
    specimens <- c(specimens, specimen)
    values[[plan$group]] <- c(values[[plan$group]], row$converted)
  }
  status <- if (length(issues)) {
    "inconclusive"
  } else if (length(missing)) {
    if (
      test_time(assessed_at, "assessment time") <
        test_time(commitment$horizon, "horizon")
    ) {
      "awaiting_outcomes"
    } else {
      "inconclusive"
    }
  } else if (!protocol_followed) {
    "inconclusive"
  } else {
    "ready"
  }
  if (length(missing) && status != "awaiting_outcomes") {
    issues <- c(issues, "incomplete_planned_measurements")
  }
  if (!length(missing) && !protocol_followed) {
    issues <- c(issues, "protocol_adherence_unconfirmed")
  }
  observed <- NULL
  if (identical(status, "ready")) {
    means <- vapply(values, mean, numeric(1))
    difference <- unname(diff(means))
    if (!is.finite(difference)) {
      status <- "inconclusive"
      issues <- c(issues, "computation_failure")
    } else {
      observed <- list(
        means = means,
        difference = difference,
        n = lengths(values)
      )
      status <- if (
        difference >= commitment$prediction$lower &&
          difference <= commitment$prediction$upper
      ) {
        "within_prediction"
      } else {
        "outside_prediction"
      }
    }
  }
  list(
    commitment_id = commitment$id,
    evidence_ids = evidence_ids,
    observation_ids = observation_ids,
    status = status,
    issues = unique(issues),
    missing_ids = missing,
    excluded_ids = unique(excluded),
    observed = observed,
    protocol_followed = protocol_followed,
    assessed_at = assessed_at,
    interpretation = if (commitment$design == "intervention") {
      "This checks the frozen prediction, not whether the claim is true. Causal interpretation still depends on assignment, adherence and the stated design."
    } else {
      "This checks the frozen prediction, not whether the claim is true. This observational comparison alone does not establish a causal effect."
    }
  )
}

validate_tests <- function(x) {
  for (field in c("commitments", "assessments")) {
    if (
      !is.null(x[[field]]) && (x$schema_version < 7 || !is.list(x[[field]]))
    ) {
      abort_suppose("Invalid prospective-test collection.", "record")
    }
  }
  all_observations <- vapply(
    x$observations,
    function(a) a$data$id,
    character(1)
  )
  seen <- character()
  for (c in x$commitments) {
    check_seal(c, "suppose_test_commitment")
    check_count(c$revision, "commitment revision", 1, length(x$revisions))
    e <- x$revisions[[c$revision]]
    if (
      !identical(c$record_id, x$record_id) ||
        !identical(c$claim_id, e$claim$id) ||
        is.null(e$candidate) ||
        !identical(c$prior_id, e$candidate$id) ||
        !all(c$context_observation_ids %in% all_observations) ||
        !all(c$basis_observation_ids %in% c$context_observation_ids)
    ) {
      abort_suppose(
        "Commitment references disagree with the retained scientific basis.",
        "revision"
      )
    }
    if (c$id %in% seen || (!is.null(c$replaces) && !c$replaces %in% seen)) {
      abort_suppose("Commitment ancestry is invalid or duplicated.", "revision")
    }
    seen <- c(seen, c$id)
    for (nm in c("source", "protocol", "author", "reason", "design_details")) {
      check_text(c[[nm]], nm)
    }
    if (
      test_time(c$horizon, "horizon") <=
        test_time(c$created_at, "commitment time") ||
        !c$design %in% c("observational", "intervention") ||
        !isTRUE(c$independent) ||
        !isTRUE(c$outcomes_unseen) ||
        !identical(c$rule$method, "normal-planned-mean-difference-v1")
    ) {
      abort_suppose("Invalid frozen test design or timing.", "record")
    }
    if (!is.list(c$planned) || !length(c$planned)) {
      abort_suppose("The frozen measurement plan is missing.", "record")
    }
    planned <- data.frame(
      observation_id = vapply(c$planned, `[[`, character(1), "observation_id"),
      condition = vapply(c$planned, `[[`, character(1), "condition")
    )
    rebuilt <- test_plan(
      planned,
      unlist(c$condition_map),
      e$candidate$conditions
    )
    if (
      !identical(json_data(rebuilt), json_data(c$planned)) ||
        !identical(c$prediction$units, e$candidate$claim$units)
    ) {
      abort_suppose(
        "Frozen measurement mapping or prediction units disagree.",
        "record"
      )
    }
    if (!is.null(c$update_id)) {
      u <- Filter(
        function(a) identical(a$id, c$update_id) && a$revision == c$revision,
        x$updates
      )
      if (
        length(u) != 1L ||
          !setequal(u[[1]]$result$observation_ids, c$basis_observation_ids)
      ) {
        abort_suppose(
          "The commitment's retained update basis is missing.",
          "revision"
        )
      }
    } else if (length(c$basis_observation_ids)) {
      abort_suppose(
        "A prior-only commitment cannot claim an update data basis.",
        "record"
      )
    }
  }
  previous <- list()
  for (a in x$assessments) {
    check_seal(a, "suppose_test_assessment")
    c <- find_test(x, a$commitment_id)
    for (nm in c("author", "reason")) {
      check_text(a[[nm]], nm)
    }
    prior_assessment <- previous[[a$commitment_id]]
    if (
      !identical(a$supersedes, prior_assessment$id) ||
        test_time(a$assessed_at, "assessment time") <
          test_time(c$created_at, "commitment time") ||
        (!is.null(prior_assessment) &&
          test_time(a$assessed_at, "assessment time") <
            test_time(prior_assessment$assessed_at, "previous assessment time"))
    ) {
      abort_suppose("Assessment history or timing is inconsistent.", "revision")
    }
    evidence <- Filter(function(o) o$id %in% a$evidence_ids, x$observations)
    if (
      !setequal(vapply(evidence, `[[`, character(1), "id"), a$evidence_ids) ||
        !setequal(
          vapply(evidence, function(o) o$data$id, character(1)),
          a$observation_ids
        )
    ) {
      abort_suppose(
        "Assessment evidence references are missing or inconsistent.",
        "revision"
      )
    }
    if (
      !a$status %in%
        c(
          "awaiting_outcomes",
          "inconclusive",
          "within_prediction",
          "outside_prediction"
        ) ||
        (a$status %in%
          c("within_prediction", "outside_prediction") &&
          (is.null(a$observed) ||
            length(a$missing_ids) ||
            length(a$issues) ||
            !isTRUE(a$protocol_followed)))
    ) {
      abort_suppose(
        "Assessment outcome is inconsistent with its completeness or provenance.",
        "record"
      )
    }
    previous[[a$commitment_id]] <- a
  }
  invisible(x)
}

test_inventory <- function(x) {
  lapply(x$commitments, function(c) {
    results <- Filter(
      function(a) identical(a$commitment_id, c$id),
      x$assessments
    )
    list(
      id = c$id,
      revision = c$revision,
      claim_id = c$claim_id,
      prior_id = c$prior_id,
      update_id = c$update_id,
      source = c$source,
      protocol = c$protocol,
      design = c$design,
      design_details = c$design_details,
      created_at = c$created_at,
      horizon = c$horizon,
      prediction = c$prediction,
      rule = c$rule,
      planned = c$planned,
      replaces = c$replaces,
      latest_assessment = if (length(results)) {
        plain(utils::tail(results, 1)[[1]])
      } else {
        NULL
      }
    )
  })
}

test_prediction_text <- function(c) {
  p <- c$prediction
  sprintf(
    "For %d and %d planned measurements, the frozen %.1f%% prediction interval for the second group mean minus the first is %.3g to %.3g %s. All planned measurements are required; a value inside this interval does not prove the claim.",
    p$planned_n[1],
    p$planned_n[2],
    100 * p$coverage,
    p$lower,
    p$upper,
    p$units
  )
}

test_status_label <- function(status) {
  switch(
    status,
    awaiting_outcomes = "Waiting for planned measurements",
    inconclusive = "Inconclusive",
    within_prediction = "Within the frozen prediction",
    outside_prediction = "Outside the frozen prediction",
    status
  )
}
