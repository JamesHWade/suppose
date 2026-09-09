regression_selected_fit <- function(entry) {
  Filter(function(f) identical(f$label, entry$choice), entry$result$fits)[[1]]
}

regression_matrix_rows <- function(x) {
  # Cholesky inversion can produce signed zero; JSON readers normalize it.
  x[x == 0] <- 0
  lapply(seq_len(nrow(x)), function(i) unname(x[i, ]))
}

regression_joint_prediction <- function(entry, settings, coverage) {
  check_number(coverage, "coverage", 0.01, 0.999)
  f <- regression_selected_fit(entry)
  p <- f$posterior
  marginal <- predict_regression(entry$result, settings, entry$choice)
  design <- regression_model_matrix(
    list(predictors = as.list(settings)),
    entry$result$spec$transforms,
    f$terms[-1]
  )
  v <- do.call(rbind, p$v)
  mean_factor <- design %*% v %*% t(design)
  scale <- p$rate / p$shape * (diag(nrow(settings)) + mean_factor)
  location <- drop(design %*% p$mean)
  if (!all(is.finite(c(scale, location)))) {
    abort_suppose(
      "The joint prediction exceeds the numerical range.",
      "computation"
    )
  }
  chol(scale)
  list(
    location = location,
    scale = regression_matrix_rows(scale),
    mean_scale = regression_matrix_rows(p$rate / p$shape * mean_factor),
    df = 2 * p$shape,
    coverage = coverage,
    units = entry$result$spec$units,
    joint_cutoff = nrow(settings) *
      stats::qf(coverage, nrow(settings), 2 * p$shape),
    outside_observed_range = vapply(
      marginal$rows,
      `[[`,
      logical(1),
      "outside_observed_range"
    ),
    method = "joint-multivariate-student-t-v1"
  )
}

regression_planned_rows <- function(entry, planned, rule) {
  fields <- regression_selected_fit(entry)$terms[-1]
  required <- c("observation_id", "condition", fields)
  if (
    !is.data.frame(planned) ||
      anyDuplicated(names(planned)) ||
      !setequal(names(planned), required)
  ) {
    abort_suppose(
      "Plan observation_id, condition labels and exactly the selected model predictors in original units.",
      "plan"
    )
  }
  check_count(nrow(planned), "planned measurements", 1, 100)
  check_strings(planned$observation_id, "planned IDs")
  check_strings(planned$condition, "condition labels")
  if (anyDuplicated(planned$observation_id)) {
    abort_suppose("Planned IDs must be unique.", "identity")
  }
  if (
    rule == "mean_difference" &&
      !setequal(unique(planned$condition), c("A", "B"))
  ) {
    abort_suppose(
      "The mean-difference rule needs at least one planned measurement in groups A and B, and no other groups.",
      "plan"
    )
  }
  predict_regression(entry$result, planned[fields], entry$choice)
  planned[c("observation_id", "condition", fields)]
}

regression_future_ids <- function(x, source) {
  unique(c(
    unlist(lapply(
      Filter(function(e) identical(e$data$source, source), x$observations),
      function(e) vapply(e$data$rows, `[[`, character(1), "observation_id")
    )),
    unlist(lapply(
      Filter(
        function(e) identical(e$data$source, source),
        x$regression_test_data
      ),
      function(e) vapply(e$data$rows, `[[`, character(1), "observation_id")
    ))
  ))
}

#' Preview a prospective regression test
#'
#' Freezes an explicit rule only when passed to [commit_regression_test()].
#' The joint-outcome rule uses one multivariate Student-t prediction region:
#' the squared Mahalanobis distance divided by the number of outcomes is compared
#' with an F quantile. This handles dependence and multiplicity jointly, rather
#' than treating marginal intervals as simultaneous intervals.
#' The mean-difference rule compares the future sample mean in B minus A with one
#' exact Student-t interval; its variance includes future measurement noise.
#' Both rules require every planned measurement and do not permit partial tests.
#' @param x Record with a reviewed regression.
#' @param regression_id Retained chosen regression-entry ID.
#' @param planned Data frame with unique `observation_id`, `condition` labels,
#'   and exactly the selected numeric predictors in their original units.
#'   Mean differences require labels A and B; the joint rule allows any labels.
#' @param source,protocol Identifiers for the future outcomes and collection protocol.
#' @param horizon Future collection deadline, as a UTC ISO 8601 timestamp.
#' @param target Scientific target and what the planned outcomes would challenge.
#' @param design `observational` or `intervention`.
#' @param design_details Sampling or assignment procedure and limitations.
#' @param rule `joint_outcomes` or `mean_difference`.
#' @param coverage Predictive probability, 0.01 to 0.999.
#' @param plan_id Optional reviewed research-plan ID; its chosen setting and
#'   replicate count must match this plan. A declined plan cannot be committed.
#' @param replaces Optional earlier regression commitment being superseded.
#' @return A sealed preview with joint prediction, fixed settings and references.
#' @export
plan_regression_test <- function(
  x,
  regression_id,
  planned,
  source,
  protocol,
  horizon,
  target,
  design = c("observational", "intervention"),
  design_details,
  rule = c("joint_outcomes", "mean_difference"),
  coverage = 0.9,
  plan_id = NULL,
  replaces = NULL
) {
  validate_record(x)
  entry <- research_regression(x, regression_id)
  research_current_model(x, entry)
  rule <- match.arg(rule)
  design <- match.arg(design)
  for (name in c("source", "protocol", "target", "design_details")) {
    check_text(get(name), name)
  }
  if (test_time(horizon, "horizon") <= test_time(now_utc(), "current time")) {
    abort_suppose("Choose a future collection deadline.", "horizon")
  }
  planned <- regression_planned_rows(entry, planned, rule)
  if (any(planned$observation_id %in% regression_future_ids(x, source))) {
    abort_suppose(
      "Planned IDs are already present in this source. Existing outcomes cannot become a prospective test.",
      "exposure"
    )
  }
  if (!is.null(replaces)) {
    regression_commitment(x, replaces)
  }
  if (!is.null(plan_id)) {
    review <- research_plan(x, plan_id)
    if (
      review$choice == "none" ||
        !identical(review$design$regression_id, regression_id)
    ) {
      abort_suppose(
        "Choose a nondeclined research plan for this exact regression.",
        "plan"
      )
    }
    chosen <- Filter(
      function(c) c$candidate_id == review$choice,
      review$design$candidates
    )[[1]]
    if (
      nrow(planned) != chosen$repeats ||
        !all(vapply(
          names(chosen$predictors),
          function(n) all(planned[[n]] == chosen$predictors[[n]]),
          logical(1)
        ))
    ) {
      abort_suppose(
        "Future settings and replicate count must match the reviewed plan's choice. Revise the planning review or leave plan_id unset for a separate test.",
        "plan"
      )
    }
  }
  f <- regression_selected_fit(entry)
  prediction <- regression_joint_prediction(
    entry,
    planned[f$terms[-1]],
    coverage
  )
  if (rule == "mean_difference") {
    weights <- ifelse(
      planned$condition == "B",
      1 / sum(planned$condition == "B"),
      -1 / sum(planned$condition == "A")
    )
    mean <- sum(weights * prediction$location)
    scale <- sqrt(drop(
      t(weights) %*% do.call(rbind, prediction$scale) %*% weights
    ))
    latent_scale <- sqrt(max(
      0,
      drop(t(weights) %*% do.call(rbind, prediction$mean_scale) %*% weights)
    ))
    q <- stats::qt((1 + coverage) / 2, prediction$df)
    prediction$contrast <- list(
      weights = weights,
      mean = mean,
      scale = scale,
      lower = mean - q * scale,
      upper = mean + q * scale,
      population_mean_scale = latent_scale,
      interpretation = "The assessed statistic is the future sample mean difference, not the unobserved population mean difference."
    )
  }
  seal(
    list(
      record_id = x$record_id,
      basis_id = proposal_basis_id(x),
      regression_id = entry$id,
      fit_id = entry$result$id,
      model = entry$choice,
      revision = entry$result$spec$revision,
      claim_id = entry$result$spec$claim_id,
      planned = lapply(seq_len(nrow(planned)), function(i) {
        as.list(planned[i, , drop = FALSE])
      }),
      predictor_units = entry$result$spec$predictor_units[f$terms[-1]],
      prediction = prediction,
      source = source,
      protocol = protocol,
      horizon = horizon,
      target = target,
      design = design,
      design_details = design_details,
      rule = rule,
      plan_id = plan_id,
      replaces = replaces,
      assumptions = c(
        entry$result$spec$assumptions,
        "Unknown common noise and joint coefficient uncertainty are integrated out. All planned outcomes are required; no optional stopping or partial comparison.",
        "Sources, unseen outcomes, settings and protocol adherence are declarations, not authenticated proof or causal identification."
      ),
      created_at = now_utc()
    ),
    "suppose_regression_test_plan"
  )
}

#' Freeze a reviewed regression test before observing outcomes
#' @param x Record used for the preview.
#' @param plan Preview from [plan_regression_test()].
#' @param author,reason Person committing and scientific reason.
#' @param independent,outcomes_unseen Explicit confirmations of independent units
#'   and no examination of the designated outcomes.
#' @param form_draft Optional original chat draft retained as provenance.
#' @return Record with an immutable regression commitment; no experiment is run.
#' @export
commit_regression_test <- function(
  x,
  plan,
  author,
  reason,
  independent = FALSE,
  outcomes_unseen = FALSE,
  form_draft = NULL
) {
  validate_record(x)
  check_seal(plan, "suppose_regression_test_plan")
  check_text(author, "author")
  check_text(reason, "reason")
  if (!isTRUE(independent) || !isTRUE(outcomes_unseen)) {
    abort_suppose(
      "Confirm independent units and unexamined designated outcomes before freezing.",
      "review"
    )
  }
  if (!identical(plan$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Preview the regression test again.",
      "stale"
    )
  }
  now <- now_utc()
  if (test_time(plan$horizon, "horizon") <= test_time(now, "freeze time")) {
    abort_suppose(
      "The deadline has passed. Prepare a new future test.",
      "horizon"
    )
  }
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      form_draft$form != "regression_test" ||
        !identical(form_draft$base_id, plan$basis_id)
    ) {
      abort_suppose("Regression-test draft references disagree.", "reference")
    }
  }
  plan$form_draft <- form_draft
  plan$preview_id <- plan$id
  plan[c("id", "type")] <- NULL
  plan$author <- author
  plan$reason <- reason
  plan$independent <- TRUE
  plan$outcomes_unseen <- TRUE
  plan$created_at <- now
  x$regression_commitments <- c(
    x$regression_commitments,
    list(seal(unclass(plan), "suppose_regression_commitment"))
  )
  x$schema_version <- 13L
  validate_record(x)
  x
}

regression_commitment <- function(x, id) {
  check_text(id, "commitment_id")
  found <- Filter(function(e) identical(e$id, id), x$regression_commitments)
  if (length(found) != 1L) {
    abort_suppose(
      "Select a frozen regression test in this record.",
      "reference"
    )
  }
  found[[1]]
}

#' Retain future regression measurements or an attributed correction
#'
#' Original evidence stays in the record. A correction must replace the exact
#' same IDs as one active attachment, with a reason; it cannot delete outcomes.
#' Completing previously missing outcomes is also an explicit correction.
#' Assessments retain the evidence versions they used and are never rewritten.
#' @param x Record containing the frozen test.
#' @param commitment_id Frozen regression test ID.
#' @param data Data frame containing the planned IDs, condition and predictor
#'   columns, plus outcome, batch, specimen and observed_at. Missing outcomes may
#'   be NA; settings must be finite. A subset of the planned IDs is allowed.
#' @param source,protocol,units Actual outcome source, collection protocol and units.
#' @param predictor_units Named character vector with actual predictor units.
#' @param author,reason Attributed import/correction explanation.
#' @param outcomes_unseen Explicit declaration that these outcomes were unseen
#'   when the commitment was made.
#' @param supersedes Optional active attachment ID being corrected.
#' @return Record with an appended, versioned measurement attachment.
#' @export
record_regression_test_data <- function(
  x,
  commitment_id,
  data,
  source,
  protocol,
  units,
  predictor_units,
  author,
  reason,
  outcomes_unseen = FALSE,
  supersedes = NULL
) {
  validate_record(x)
  c <- regression_commitment(x, commitment_id)
  if (!isTRUE(outcomes_unseen)) {
    abort_suppose(
      "Declare that these outcomes were unexamined when the test was frozen.",
      "exposure"
    )
  }
  check_text(reason, "reason")
  fields <- names(c$predictor_units)
  base <- c(
    "observation_id",
    "condition",
    "outcome",
    "batch",
    "specimen",
    "observed_at"
  )
  if (
    !is.data.frame(data) ||
      anyDuplicated(names(data)) ||
      !setequal(names(data), c(base, fields))
  ) {
    abort_suppose(
      "Supply the planned identifiers and predictors plus outcome, batch, specimen and observed_at.",
      "data"
    )
  }
  ids <- vapply(c$planned, `[[`, character(1), "observation_id")
  if (!nrow(data) || !all(data$observation_id %in% ids)) {
    abort_suppose("Attach only IDs from this frozen test.", "identity")
  }
  for (n in fields) {
    if (!is.numeric(data[[n]]) || !all(is.finite(data[[n]]))) {
      abort_suppose("Actual predictor settings must be finite numbers.", "data")
    }
  }
  check_strings(predictor_units, "predictor_units")
  if (
    anyDuplicated(names(predictor_units)) ||
      !setequal(names(predictor_units), fields)
  ) {
    abort_suppose("Name the actual unit for each selected predictor.", "units")
  }
  observations <- import_observations(
    data[base],
    source,
    protocol,
    author,
    units,
    role = "assessment",
    exposure = "unseen"
  )
  active <- regression_active_test_data(x, commitment_id)
  if (!is.null(supersedes)) {
    old <- Filter(function(e) identical(e$id, supersedes), active)
    if (
      length(old) != 1L ||
        !setequal(
          vapply(old[[1]]$data$rows, `[[`, character(1), "observation_id"),
          data$observation_id
        )
    ) {
      abort_suppose(
        "Correct one active attachment using exactly its original measurement IDs.",
        "correction"
      )
    }
    active <- Filter(function(e) !identical(e$id, supersedes), active)
  }
  existing <- unlist(lapply(active, function(e) {
    vapply(e$data$rows, `[[`, character(1), "observation_id")
  }))
  if (any(data$observation_id %in% existing)) {
    abort_suppose(
      "These IDs are already attached. Select the active attachment to correct them explicitly.",
      "duplicate"
    )
  }
  attachment <- seal(
    list(
      commitment_id = commitment_id,
      data = observations,
      settings = lapply(seq_len(nrow(data)), function(i) {
        as.list(data[i, c("observation_id", fields), drop = FALSE])
      }),
      predictor_units = as.list(predictor_units[fields]),
      author = author,
      reason = reason,
      supersedes = supersedes,
      created_at = now_utc()
    ),
    "suppose_regression_test_data"
  )
  x$regression_test_data <- c(x$regression_test_data, list(attachment))
  x$schema_version <- 13L
  validate_record(x)
  x
}

regression_active_test_data <- function(x, id) {
  entries <- Filter(
    function(e) identical(e$commitment_id, id),
    x$regression_test_data
  )
  replaced <- vapply(entries, function(e) e$supersedes %||% "", character(1))
  Filter(function(e) !e$id %in% replaced, entries)
}

regression_test_evaluation <- function(
  x,
  commitment,
  protocol_followed,
  assessed_at,
  evidence = NULL
) {
  if (is.null(evidence)) {
    evidence <- regression_active_test_data(x, commitment$id)
  }
  issues <- missing <- specimens <- character()
  rows <- settings <- list()
  for (e in evidence) {
    d <- e$data
    if (!identical(d$source, commitment$source)) {
      issues <- c(issues, "source_mismatch")
    }
    if (!identical(d$protocol, commitment$protocol)) {
      issues <- c(issues, "protocol_mismatch")
    }
    if (
      !identical(d$target_units, commitment$prediction$units) ||
        !identical(e$predictor_units, commitment$predictor_units)
    ) {
      issues <- c(issues, "units_mismatch")
    }
    if (d$role != "assessment" || d$exposure != "unseen") {
      issues <- c(issues, "ineligible_exposure")
    }
    if (
      test_time(d$created_at, "import time") <
        test_time(commitment$created_at, "freeze time")
    ) {
      issues <- c(issues, "import_before_commitment")
    }
    rows <- c(rows, d$rows)
    settings <- c(settings, e$settings)
  }
  values <- rep(NA_real_, length(commitment$planned))
  for (i in seq_along(commitment$planned)) {
    plan <- commitment$planned[[i]]
    found <- Filter(
      function(r) identical(r$observation_id, plan$observation_id),
      rows
    )
    if (length(found) > 1L) {
      issues <- c(issues, "ambiguous_measurement_versions")
      next
    }
    if (!length(found) || is.null(found[[1]]$converted)) {
      missing <- c(missing, plan$observation_id)
      next
    }
    row <- found[[1]]
    actual <- Filter(
      function(r) identical(r$observation_id, plan$observation_id),
      settings
    )
    if (
      length(actual) != 1L ||
        !all(vapply(
          names(commitment$predictor_units),
          function(n) {
            identical(as.numeric(actual[[1]][[n]]), as.numeric(plan[[n]]))
          },
          logical(1)
        ))
    ) {
      issues <- c(issues, "predictor_setting_mismatch")
    }
    if (!identical(row$condition, plan$condition)) {
      issues <- c(issues, "condition_mismatch")
    }
    if (identical(row$observed_at, "unknown")) {
      issues <- c(issues, "unknown_observation_time")
    } else {
      time <- test_time(row$observed_at, "observation time")
      if (time <= test_time(commitment$created_at, "freeze time")) {
        issues <- c(issues, "outcome_before_or_at_commitment")
      }
      if (time > test_time(commitment$horizon, "deadline")) {
        issues <- c(issues, "outcome_after_deadline")
      }
      if (time > test_time(assessed_at, "assessment time")) {
        issues <- c(issues, "future_dated_outcome")
      }
    }
    unit <- object_id(list(row$batch, row$specimen))
    if (unit %in% specimens) {
      issues <- c(issues, "repeated_measurement_unit")
    }
    specimens <- c(specimens, unit)
    values[i] <- row$converted
  }
  if (!length(missing) && !isTRUE(protocol_followed)) {
    issues <- c(issues, "protocol_adherence_unconfirmed")
  }
  status <- if (length(issues)) {
    "inconclusive"
  } else if (length(missing)) {
    if (
      test_time(assessed_at, "assessment time") <
        test_time(commitment$horizon, "deadline")
    ) {
      "awaiting_outcomes"
    } else {
      "inconclusive"
    }
  } else {
    "ready"
  }
  if (length(missing) && status != "awaiting_outcomes") {
    issues <- c(issues, "incomplete_planned_measurements")
  }
  observed <- NULL
  if (status == "ready") {
    p <- commitment$prediction
    if (commitment$rule == "mean_difference") {
      value <- sum(p$contrast$weights * values)
      within <- value >= p$contrast$lower && value <= p$contrast$upper
      observed <- list(
        statistic = "future_sample_mean_B_minus_A",
        value = value,
        lower = p$contrast$lower,
        upper = p$contrast$upper
      )
    } else {
      difference <- values - p$location
      # Cholesky solve avoids forming an inverse of the joint predictive scale.
      z <- backsolve(
        chol(do.call(rbind, p$scale)),
        difference,
        transpose = TRUE
      )
      value <- sum(z^2)
      within <- value <= p$joint_cutoff
      observed <- list(
        statistic = "joint_squared_mahalanobis_distance",
        value = value,
        cutoff = p$joint_cutoff
      )
    }
    if (!is.finite(value)) {
      issues <- c(issues, "computation_failure")
      status <- "inconclusive"
      observed <- NULL
    } else {
      status <- if (within) "within_prediction" else "outside_prediction"
    }
  }
  list(
    commitment_id = commitment$id,
    evidence_ids = vapply(evidence, `[[`, character(1), "id"),
    status = status,
    issues = unique(issues),
    missing_ids = missing,
    observed = observed,
    protocol_followed = isTRUE(protocol_followed),
    assessed_at = assessed_at,
    interpretation = "This checks the original frozen prediction under its collection assumptions. It does not establish truth, causality, decision utility or global model adequacy."
  )
}

#' Assess a frozen regression prediction without refitting
#' @param x Record with the commitment and any attached future measurements.
#' @param commitment_id Frozen regression commitment ID.
#' @param author,reason Reviewer and reason for this assessment.
#' @param protocol_followed Explicit confirmation that the committed collection
#'   and independent-unit protocol was followed.
#' @return Record with a new assessment referring to exact evidence versions.
#' @export
assess_regression_test <- function(
  x,
  commitment_id,
  author,
  reason,
  protocol_followed = FALSE
) {
  validate_record(x)
  check_text(author, "author")
  check_text(reason, "reason")
  if (
    !is.logical(protocol_followed) ||
      length(protocol_followed) != 1L ||
      is.na(protocol_followed)
  ) {
    abort_suppose("Protocol adherence must be TRUE or FALSE.", "review")
  }
  c <- regression_commitment(x, commitment_id)
  result <- regression_test_evaluation(x, c, protocol_followed, now_utc())
  previous <- Filter(
    function(a) identical(a$commitment_id, commitment_id),
    x$regression_assessments
  )
  prior <- if (length(previous)) utils::tail(previous, 1)[[1]] else NULL
  signature <- function(z) {
    object_id(z[c(
      "evidence_ids",
      "status",
      "issues",
      "missing_ids",
      "observed",
      "protocol_followed"
    )])
  }
  if (!is.null(prior) && identical(signature(prior), signature(result))) {
    abort_suppose(
      "This assessment is already retained for the same evidence and outcome.",
      "duplicate"
    )
  }
  result$author <- author
  result$reason <- reason
  result$supersedes <- prior$id
  x$regression_assessments <- c(
    x$regression_assessments,
    list(seal(result, "suppose_regression_assessment"))
  )
  x$schema_version <- 13L
  validate_record(x)
  x
}

validate_regression_tests <- function(x) {
  for (name in c(
    "regression_commitments",
    "regression_test_data",
    "regression_assessments"
  )) {
    if (
      !is.null(x[[name]]) && (x$schema_version < 13L || !is.list(x[[name]]))
    ) {
      abort_suppose("Invalid regression-test collection.", "record")
    }
  }
  seen <- character()
  for (c in x$regression_commitments) {
    check_seal(c, "suppose_regression_commitment")
    entry <- research_regression(x, c$regression_id)
    if (
      !identical(c$record_id, x$record_id) ||
        !identical(c$fit_id, entry$result$id) ||
        !identical(c$model, entry$choice) ||
        !identical(c$claim_id, entry$result$spec$claim_id) ||
        c$revision != entry$result$spec$revision
    ) {
      abort_suppose("Frozen regression references disagree.", "reference")
    }
    if (c$id %in% seen || (!is.null(c$replaces) && !c$replaces %in% seen)) {
      abort_suppose("Regression commitment ancestry is invalid.", "reference")
    }
    if (
      !isTRUE(c$independent) ||
        !isTRUE(c$outcomes_unseen) ||
        !c$rule %in% c("joint_outcomes", "mean_difference") ||
        test_time(c$horizon, "deadline") <=
          test_time(c$created_at, "freeze time")
    ) {
      abort_suppose("Invalid frozen regression rule or timing.", "record")
    }
    if (
      !is.null(c$plan_id) &&
        !identical(
          research_plan(x, c$plan_id)$design$regression_id,
          c$regression_id
        )
    ) {
      abort_suppose("The frozen planning reference disagrees.", "reference")
    }
    seen <- c(seen, c$id)
  }
  seen_data <- character()
  replaced <- character()
  for (e in x$regression_test_data) {
    check_seal(e, "suppose_regression_test_data")
    check_seal(e$data, "suppose_observations")
    c <- regression_commitment(x, e$commitment_id)
    ids <- vapply(e$data$rows, `[[`, character(1), "observation_id")
    if (
      !all(ids %in% vapply(c$planned, `[[`, character(1), "observation_id"))
    ) {
      abort_suppose("Test data contains unplanned IDs.", "identity")
    }
    if (!is.null(e$supersedes)) {
      parent <- Filter(
        function(p) identical(p$id, e$supersedes),
        x$regression_test_data
      )
      if (
        !e$supersedes %in% seen_data ||
          e$supersedes %in% replaced ||
          length(parent) != 1L ||
          !identical(parent[[1]]$commitment_id, e$commitment_id) ||
          !setequal(
            ids,
            vapply(parent[[1]]$data$rows, `[[`, character(1), "observation_id")
          )
      ) {
        abort_suppose("Test-data correction ancestry is invalid.", "reference")
      }
      replaced <- c(replaced, e$supersedes)
    }
    if (e$id %in% seen_data) {
      abort_suppose("Duplicated regression evidence.", "duplicate")
    }
    seen_data <- c(seen_data, e$id)
  }
  previous <- list()
  for (a in x$regression_assessments) {
    check_seal(a, "suppose_regression_assessment")
    c <- regression_commitment(x, a$commitment_id)
    evidence <- Filter(
      function(e) e$id %in% a$evidence_ids,
      x$regression_test_data
    )
    if (
      !setequal(a$evidence_ids, vapply(evidence, `[[`, character(1), "id")) ||
        !all(vapply(
          evidence,
          function(e) identical(e$commitment_id, c$id),
          logical(1)
        )) ||
        !identical(a$supersedes, previous[[c$id]]$id)
    ) {
      abort_suppose("Regression assessment references disagree.", "reference")
    }
    if (
      test_time(a$assessed_at, "assessment time") <
        test_time(c$created_at, "freeze time") ||
        any(vapply(
          evidence,
          function(e) {
            test_time(e$created_at, "evidence time") >
              test_time(a$assessed_at, "assessment time")
          },
          logical(1)
        ))
    ) {
      abort_suppose("Regression assessment timing is inconsistent.", "time")
    }
    rebuilt <- regression_test_evaluation(
      x,
      c,
      a$protocol_followed,
      a$assessed_at,
      evidence
    )
    fields <- c(
      "evidence_ids",
      "status",
      "issues",
      "missing_ids",
      "protocol_followed"
    )
    # JSON decimal round trips can change the final floating-point bit of the
    # recomputed quadratic form; categorical decisions must still match exactly.
    if (
      !identical(json_data(a[fields]), json_data(rebuilt[fields])) ||
        !isTRUE(all.equal(a$observed, rebuilt$observed, tolerance = 1e-12))
    ) {
      abort_suppose(
        "Regression assessment disagrees with its frozen evidence.",
        "integrity"
      )
    }
    previous[[c$id]] <- a
  }
  invisible(x)
}

regression_test_inventory <- function(x) {
  lapply(x$regression_commitments, function(c) {
    list(
      commitment = c,
      assessments = Filter(
        function(a) identical(a$commitment_id, c$id),
        x$regression_assessments
      ),
      active_evidence = vapply(
        regression_active_test_data(x, c$id),
        `[[`,
        character(1),
        "id"
      )
    )
  })
}
