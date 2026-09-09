#' Compare next measurements using a retained regression
#'
#' Uses alloptr's exact normal/inverse-gamma BED calculation. Each candidate is
#' an alternative experiment with independent replicates at one setting. The
#' target is the mean at the second contrast row minus the first. `estimate`
#' minimizes squared-error loss for that contrast; `decide` minimizes expected
#' opportunity loss between those two protocols under linear utility.
#'
#' For decisions, `threshold` is the outcome-equivalent penalty of choosing the
#' second protocol. It is an explicit preference, not inferred from scientific
#' usefulness or observed data. Experiment costs are separate: candidate `cost`
#' must be in squared outcome units for estimation or outcome-equivalent utility
#' units for decisions. Use zero cost explicitly when comparing learning benefits
#' under the replicate budget alone. No dollars-to-outcome conversion is inferred.
#'
#' @param x A record with a retained regression choice other than `neither`.
#' @param regression_id ID of that reviewed regression entry.
#' @param candidates Data frame with `candidate_id`, selected model predictor
#'   columns in original units, `repeats` (1 to 100), `cost` (nonnegative total
#'   experiment cost), and `feasible` (logical). One to 100 alternatives.
#' @param contrast Two-row data frame with exactly the selected predictor columns.
#' @param purpose `estimate` or `decide`.
#' @param threshold Outcome-equivalent preference threshold; default zero.
#' @param max_units Maximum independent units available for an experiment, 1 to 100.
#' @param rationale Scientific purpose, protocol, feasibility and cost assumptions.
#' @param preference Explicit utility/preference explanation; required for `decide`.
#' @param source_plan_id Optional reviewed plan ID when revising its settings.
#' @return A sealed preview with references, costs, eligibility, exact benefits,
#'   ties and inherited model-check limitations. No experiment is authorized,
#'   executed, frozen as a prospective test or retained automatically.
#' @export
design_regression <- function(
  x,
  regression_id,
  candidates,
  contrast,
  purpose = "estimate",
  threshold = 0,
  max_units = 6L,
  rationale,
  preference = "",
  source_plan_id = NULL
) {
  validate_record(x)
  rlang::check_installed(
    "alloptr",
    reason = "to calculate Bayesian design benefits"
  )
  if (!"bed_normal_contrast" %in% getNamespaceExports("alloptr")) {
    abort_suppose(
      "Install alloptr with bed_normal_contrast() support.",
      "dependency"
    )
  }
  entry <- research_regression(x, regression_id)
  if (!is.null(source_plan_id)) {
    original <- research_plan(x, source_plan_id)
    if (!identical(original$design$regression_id, regression_id)) {
      abort_suppose(
        "A resumed plan must keep its original model. Start a new plan to use a different model.",
        "stale"
      )
    }
    research_current_model(x, entry)
  }
  result <- entry$result
  f <- Filter(function(f) identical(f$label, entry$choice), result$fits)[[1]]
  fields <- f$terms[-1]
  check_text(purpose, "purpose")
  if (!purpose %in% c("estimate", "decide")) {
    abort_suppose("Choose estimate or decide as the research purpose.")
  }
  check_text(rationale, "rationale")
  check_number(threshold, "threshold")
  if (purpose == "decide") {
    check_text(preference, "preference")
  }
  if (purpose == "estimate" && threshold != 0) {
    abort_suppose(
      "An estimation design does not use a decision threshold; set it to zero."
    )
  }
  check_number(max_units, "max_units", 1, 100)
  if (max_units != floor(max_units)) {
    abort_suppose("The unit budget must be a whole number.")
  }
  required <- c("candidate_id", fields, "repeats", "cost", "feasible")
  if (
    !is.data.frame(candidates) ||
      nrow(candidates) < 1L ||
      nrow(candidates) > 100L ||
      anyDuplicated(names(candidates)) ||
      !setequal(names(candidates), required)
  ) {
    abort_suppose(
      "Supply one to 100 candidate rows with IDs, model predictors, repeats, cost and feasible."
    )
  }
  check_strings(candidates$candidate_id, "candidate_id")
  if (
    "none" %in%
      candidates$candidate_id ||
      anyDuplicated(candidates$candidate_id) ||
      !all(nzchar(trimws(candidates$candidate_id)))
  ) {
    abort_suppose(
      "Candidate IDs must be nonempty, unique, and different from none."
    )
  }
  if (!is.logical(candidates$feasible) || anyNA(candidates$feasible)) {
    abort_suppose(
      "Candidate feasibility must be explicit TRUE or FALSE values."
    )
  }
  if (
    !is.numeric(candidates$cost) ||
      any(!is.finite(candidates$cost) | candidates$cost < 0)
  ) {
    abort_suppose(
      "Experiment costs must be finite nonnegative totals in the selected loss units."
    )
  }
  if (!is.data.frame(contrast) || nrow(contrast) != 2L) {
    abort_suppose("Supply two protocol settings for the target mean contrast.")
  }
  predictions <- predict_regression(result, candidates[fields], entry$choice)
  target <- predict_regression(result, contrast, entry$choice)
  matrix_for <- function(d) {
    regression_model_matrix(
      list(predictors = as.list(d)),
      result$spec$transforms,
      fields
    )
  }
  target_matrix <- matrix_for(contrast)
  c <- drop(target_matrix[2, ] - target_matrix[1, ])
  if (all(c == 0)) {
    abort_suppose("Choose two different settings for the target contrast.")
  }
  p <- f$posterior
  computation <- alloptr::bed_normal_contrast(
    p$mean,
    do.call(rbind, p$v),
    p$shape,
    p$rate,
    matrix_for(candidates[fields]),
    c,
    candidates$repeats,
    threshold
  )
  score_name <- if (purpose == "estimate") "variance_gain" else "decision_gain"
  current_loss <- if (purpose == "estimate") {
    computation$current$contrast_variance
  } else {
    computation$current$opportunity_loss
  }
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    eligible <- candidates$feasible[i] && candidates$repeats[i] <= max_units
    gain <- computation$scores[[score_name]][i]
    list(
      candidate_id = candidates$candidate_id[i],
      predictors = as.list(candidates[i, fields, drop = FALSE]),
      repeats = candidates$repeats[i],
      cost = candidates$cost[i],
      feasible = candidates$feasible[i],
      eligible = eligible,
      benefit = gain,
      expected_remaining_loss = max(0, current_loss - gain),
      net_benefit = gain - candidates$cost[i],
      outside_observed_range = predictions$rows[[i]]$outside_observed_range
    )
  })
  eligible <- Filter(function(r) r$eligible, rows)
  best <- if (length(eligible)) {
    max(vapply(eligible, `[[`, numeric(1), "net_benefit"))
  } else {
    0
  }
  tolerance <- 1e-10 * max(1, current_loss, abs(best))
  recommended <- if (best > tolerance) {
    vapply(
      Filter(function(r) abs(r$net_benefit - best) <= tolerance, eligible),
      `[[`,
      character(1),
      "candidate_id"
    )
  } else {
    character()
  }
  seal(
    list(
      record_id = x$record_id,
      basis_id = proposal_basis_id(x),
      regression_id = regression_id,
      source_plan_id = source_plan_id,
      fit_id = result$id,
      model = entry$choice,
      purpose = purpose,
      target = lapply(seq_len(2), function(i) {
        as.list(contrast[i, , drop = FALSE])
      }),
      predictor_units = result$spec$predictor_units[fields],
      threshold = threshold,
      preference = preference,
      rationale = rationale,
      max_units = max_units,
      units = result$spec$units,
      loss_units = if (purpose == "estimate") {
        paste0(result$spec$units, " squared")
      } else {
        paste0(result$spec$units, " equivalent utility")
      },
      current = computation$current,
      current_loss = current_loss,
      candidates = rows,
      recommended = recommended,
      no_design_reason = if (length(recommended)) {
        ""
      } else {
        "No eligible candidate has positive net expected benefit at numerical resolution."
      },
      target_outside_observed_range = any(vapply(
        target$rows,
        `[[`,
        logical(1),
        "outside_observed_range"
      )),
      model_checks = lapply(f$checks, function(c) {
        c[setdiff(names(c), "replicated")]
      }),
      model_review_reason = entry$reason,
      assumptions = c(
        computation$assumptions,
        "Feasibility and cost are user-supplied assumptions; marginal range checks do not prove joint support or safe operation.",
        "Scores are conditional on this retained model, including unresolved predictive checks and observational-data limitations.",
        "This preview and any retained choice are research planning only, not an alloptr campaign proposal, execution or frozen prospective test."
      ),
      engine = list(
        package = "alloptr",
        version = as.character(utils::packageVersion("alloptr")),
        method = computation$method
      ),
      created_at = now_utc()
    ),
    "suppose_research_design"
  )
}

research_regression <- function(x, id) {
  check_text(id, "regression_id")
  entries <- Filter(function(e) identical(e$id, id), x$regressions)
  if (length(entries) != 1L || identical(entries[[1]]$choice, "neither")) {
    abort_suppose(
      "Select a retained regression with a chosen model, not neither.",
      "incomplete"
    )
  }
  entries[[1]]
}

#' Retain a reviewed research design choice
#' @param x A record.
#' @param design A preview from [design_regression()].
#' @param choice Candidate ID or `none`.
#' @param author,reason Reviewer and rationale, including unresolved limitations.
#' @param reviewed Explicit confirmation of reviewing feasibility, independent
#'   replication, target, preferences, costs and model limitations.
#' @param form_draft Optional chat draft retained as provenance.
#' @return A record with an append-only planning review. This is not authorization
#'   to execute an experiment or evidence that a prospective test was frozen.
#' @export
record_research_design <- function(
  x,
  design,
  choice,
  author,
  reason,
  reviewed = FALSE,
  form_draft = NULL
) {
  validate_record(x)
  check_seal(design, "suppose_research_design")
  if (!isTRUE(reviewed)) {
    abort_suppose(
      "Review the design assumptions and feasibility before retaining a choice.",
      "review"
    )
  }
  if (!identical(design$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Refresh the design preview before retaining it.",
      "stale"
    )
  }
  check_text(choice, "choice")
  if (
    choice != "none" &&
      !choice %in%
        vapply(
          Filter(function(r) r$eligible, design$candidates),
          `[[`,
          character(1),
          "candidate_id"
        )
  ) {
    abort_suppose("Choose an eligible candidate or none.")
  }
  check_text(author, "author")
  check_text(reason, "reason")
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      !identical(form_draft$form, "design") ||
        !identical(form_draft$base_id, design$basis_id)
    ) {
      abort_suppose("Design draft references disagree.", "reference")
    }
  }
  entry <- seal(
    list(
      design = design,
      choice = choice,
      author = author,
      reason = reason,
      form_draft = form_draft,
      created_at = now_utc()
    ),
    "suppose_research_design_entry"
  )
  x$research_designs <- c(x$research_designs, list(entry))
  x$schema_version <- max(x$schema_version, 11L)
  validate_record(x)
  x
}

validate_research_designs <- function(x) {
  if (
    !is.null(x$research_designs) &&
      (x$schema_version < 11L || !is.list(x$research_designs))
  ) {
    abort_suppose("Invalid research design collection.", "record")
  }
  for (entry in x$research_designs) {
    check_seal(entry, "suppose_research_design_entry")
    d <- entry$design
    check_seal(d, "suppose_research_design")
    source <- research_regression(x, d$regression_id)
    if (
      !identical(d$record_id, x$record_id) ||
        !identical(d$fit_id, source$result$id) ||
        !identical(d$model, source$choice)
    ) {
      abort_suppose("Research design references disagree.", "reference")
    }
    if (!is.null(d$source_plan_id)) {
      parent <- research_plan(x, d$source_plan_id)
      order <- vapply(x$research_designs, `[[`, character(1), "id")
      if (
        match(parent$id, order) >= match(entry$id, order) ||
          !identical(parent$design$regression_id, d$regression_id)
      ) {
        abort_suppose("Research-plan ancestry is inconsistent.", "reference")
      }
    }
    if (!is.null(entry$form_draft)) {
      check_seal(entry$form_draft, "suppose_form_draft")
    }
  }
  invisible(x)
}

research_design_inventory <- function(x) {
  lapply(x$research_designs, function(e) {
    list(id = e$id, choice = e$choice, reason = e$reason, design = e$design)
  })
}

research_plan <- function(x, id) {
  check_text(id, "plan_id")
  found <- Filter(function(e) identical(e$id, id), x$research_designs)
  if (length(found) != 1L) {
    abort_suppose("Select a reviewed plan in this record.", "reference")
  }
  found[[1]]
}

research_current_model <- function(x, entry) {
  spec <- entry$result$spec
  if (
    spec$revision != length(x$revisions) ||
      !identical(spec$claim_id, utils::tail(x$revisions, 1)[[1]]$claim$id)
  ) {
    abort_suppose(
      "This model belongs to an earlier claim revision. Review a model for the current claim before creating a new plan or analysis.",
      "stale"
    )
  }
  invisible(entry)
}

#' Start new design settings from a reviewed plan
#'
#' Restores the actual reviewed settings, not the earlier chat suggestions.
#' This returns inputs only. Recompute with [design_regression()] and review
#' before retaining a new choice. The original review is unchanged.
#' @param x A record containing the reviewed research plan.
#' @param plan_id ID of a retained research-design entry.
#' @return Named inputs for [design_regression()], including source-plan identity.
#' @export
research_design_settings <- function(x, plan_id) {
  validate_record(x)
  e <- research_plan(x, plan_id)
  d <- e$design
  research_current_model(x, research_regression(x, d$regression_id))
  list(
    regression_id = d$regression_id,
    candidates = do.call(
      rbind,
      lapply(d$candidates, function(r) {
        as.data.frame(
          c(
            list(candidate_id = r$candidate_id),
            r$predictors,
            list(repeats = r$repeats, cost = r$cost, feasible = r$feasible)
          ),
          stringsAsFactors = FALSE
        )
      })
    ),
    contrast = do.call(rbind, lapply(d$target, as.data.frame)),
    purpose = d$purpose,
    threshold = d$threshold,
    max_units = d$max_units,
    rationale = d$rationale,
    preference = d$preference,
    source_plan_id = e$id
  )
}
