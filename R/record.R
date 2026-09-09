#' Start or extend a local elicitation record
#'
#' Each entry retains a complete claim and optional candidate and prediction.
#' Adding an entry never changes previous entries or their acceptance records.
#' @param x A claim for `elicitation_record()`, a record for `record_revision()`.
#' @param record_id A human-readable name for the record.
#' @param claim A claim from the same revision lineage.
#' @param candidate Optional fitted prior referencing this exact claim.
#' @param prediction Optional prediction referencing this exact prior.
#' @param reason Why this record entry was added.
#' @param judgments Optional additional judgments to retain, including unresolved
#'   answers. Candidate fitting inputs are always retained as well.
#' @param assistance Optional sealed provenance for an applied assistant proposal.
#' @return A `suppose_record`.
#' @export
elicitation_record <- function(x, record_id = "untitled") {
  check_seal(x, "suppose_claim")
  check_text(record_id, "record_id")
  structure(
    list(
      schema_version = 1L,
      record_id = record_id,
      revisions = list(list(
        claim = x,
        candidate = NULL,
        prediction = NULL,
        reason = "Initial claim",
        judgments = list(),
        acceptance = NULL
      ))
    ),
    class = c("suppose_record", "list")
  )
}

#' @rdname elicitation_record
#' @export
record_revision <- function(
  x,
  claim,
  candidate = NULL,
  prediction = NULL,
  reason,
  judgments = list(),
  assistance = NULL
) {
  validate_record(x)
  check_seal(claim, "suppose_claim")
  check_text(reason, "reason")
  previous <- x$revisions[[length(x$revisions)]]$claim
  if (claim$id != previous$id && !identical(claim$parent_id, previous$id)) {
    abort_suppose(
      "The new claim must revise the latest claim in this record.",
      "revision"
    )
  }
  entry <- list(
    claim = claim,
    candidate = candidate,
    prediction = prediction,
    reason = reason,
    judgments = merge_judgments(candidate$judgments, judgments),
    acceptance = NULL
  )
  if (!is.null(assistance)) {
    entry$assistance <- assistance
    x$schema_version <- max(x$schema_version, 2L)
  }
  validate_entry(entry)
  x$revisions[[length(x$revisions) + 1L]] <- entry
  x
}

#' Accept the latest formalization after explicit human review
#'
#' Acceptance records a person's judgment of correspondence with their meaning;
#' it does not establish scientific truth. Acceptance requires an inspectable
#' prediction, a fit within tolerance, a rationale, and a concrete challenge.
#' @param x A local record.
#' @param author Person accepting the formalization.
#' @param reason Why this candidate expresses their intended belief.
#' @param challenge Evidence or a check that could challenge the formalization.
#' @return A new record with a sealed acceptance on the latest entry.
#' @export
accept_revision <- function(x, author, reason, challenge) {
  validate_record(x)
  for (arg in c("author", "reason", "challenge")) {
    check_text(get(arg), arg)
  }
  i <- length(x$revisions)
  entry <- x$revisions[[i]]
  if (!is.null(entry$acceptance)) {
    abort_suppose(
      "This revision is already accepted; add a new revision to change it.",
      "accepted"
    )
  }
  if (is.null(entry$candidate) || is.null(entry$prediction)) {
    abort_suppose(
      "Inspect a candidate and its predictions before acceptance.",
      "incomplete"
    )
  }
  if (!isTRUE(entry$candidate$fit_ok)) {
    abort_suppose(
      "Resolve the quantile mismatch before accepting this candidate.",
      "fit"
    )
  }
  entry$acceptance <- seal(
    list(
      author = author,
      reason = reason,
      challenge = challenge,
      claim_id = entry$claim$id,
      prior_id = entry$candidate$id,
      prediction_id = entry$prediction$id,
      assistance_id = entry$assistance$id,
      created_at = now_utc()
    ),
    "suppose_acceptance"
  )
  x$revisions[[i]] <- entry
  x
}

validate_entry <- function(entry) {
  if (
    !is.list(entry) ||
      !setequal(
        setdiff(names(entry), "assistance"),
        c(
          "claim",
          "candidate",
          "prediction",
          "reason",
          "judgments",
          "acceptance"
        )
      )
  ) {
    abort_suppose("Malformed revision entry in the bundle.", "record")
  }
  if (!is.list(entry$judgments)) {
    abort_suppose("Judgments must be a list.", "record")
  }
  for (j in entry$judgments) {
    check_seal(j, "suppose_judgment")
  }
  check_seal(entry$claim, "suppose_claim")
  check_text(entry$reason, "reason")
  if (!is.null(entry$candidate)) {
    check_seal(entry$candidate, "suppose_prior")
    if (!identical(entry$candidate$claim$id, entry$claim$id)) {
      abort_suppose(
        "Candidate references a different claim revision.",
        "revision"
      )
    }
  }
  if (!is.null(entry$prediction)) {
    check_seal(entry$prediction, "suppose_prediction")
    if (
      is.null(entry$candidate) ||
        !identical(entry$prediction$prior_id, entry$candidate$id)
    ) {
      abort_suppose("Prediction references a different candidate.", "revision")
    }
  }
  if (!is.null(entry$assistance)) {
    check_seal(entry$assistance, "suppose_assistance")
    check_seal(entry$assistance$proposal, "suppose_proposal")
  }
  if (!is.null(entry$acceptance)) {
    a <- entry$acceptance
    check_seal(a, "suppose_acceptance")
    meaning <- identical(a$kind, "interpretation")
    if (
      (!meaning &&
        (is.null(entry$candidate) ||
          is.null(entry$prediction) ||
          !isTRUE(entry$candidate$fit_ok))) ||
        (meaning && (!is.null(a$prior_id) || !is.null(a$prediction_id))) ||
        !identical(a$claim_id, entry$claim$id) ||
        (!meaning && !identical(a$prior_id, entry$candidate$id)) ||
        (!meaning && !identical(a$prediction_id, entry$prediction$id)) ||
        !identical(a$assistance_id, entry$assistance$id)
    ) {
      abort_suppose(
        "Acceptance references do not match this formalization.",
        "revision"
      )
    }
    for (arg in c("author", "reason", "challenge")) {
      check_text(a[[arg]], arg)
    }
  }
  invisible(entry)
}
validate_record <- function(x) {
  if (
    !is.list(x) ||
      !is.numeric(x$schema_version) ||
      length(x$schema_version) != 1L ||
      is.na(x$schema_version) ||
      !x$schema_version %in% c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
  ) {
    abort_suppose(
      "Unsupported bundle schema; this version reads schemas 1 through 12.",
      "schema"
    )
  }
  if (
    !setequal(
      setdiff(
        names(x),
        c(
          "conversation",
          "observations",
          "updates",
          "analyses",
          "commitments",
          "assessments",
          "sensitivities",
          "model_extensions",
          "predictors",
          "regressions",
          "research_designs",
          "model_references"
        )
      ),
      c("schema_version", "record_id", "revisions")
    )
  ) {
    abort_suppose("Malformed bundle fields.", "record")
  }
  if (!is.null(x$conversation)) {
    if (x$schema_version < 3 || !is.list(x$conversation)) {
      abort_suppose("Invalid saved conversation.", "record")
    }
    for (m in x$conversation) {
      if (
        !is.list(m) ||
          !is.character(m$role) ||
          length(m$role) != 1L ||
          !m$role %in% c("user", "assistant")
      ) {
        abort_suppose("Invalid conversation role.", "record")
      }
      check_text(m$text, "message")
      check_text(m$status, "message status")
      check_text(m$created_at, "message time")
    }
  }
  if (
    !is.null(x$observations) &&
      (x$schema_version < 4 || !is.list(x$observations))
  ) {
    abort_suppose("Invalid observations collection.", "record")
  }
  if (!is.null(x$updates) && (x$schema_version < 5 || !is.list(x$updates))) {
    abort_suppose("Invalid update collection.", "record")
  }
  check_text(x$record_id, "record_id")
  if (!is.list(x$revisions) || !length(x$revisions)) {
    abort_suppose("A bundle must contain a claim revision.", "record")
  }
  previous <- NULL
  for (entry in x$revisions) {
    validate_entry(entry)
    if (
      !is.null(previous) &&
        entry$claim$id != previous$id &&
        !identical(entry$claim$parent_id, previous$id)
    ) {
      abort_suppose("Claim ancestry is broken in the bundle.", "revision")
    }
    previous <- entry$claim
  }
  validate_evidence(x)
  validate_updates(x)
  validate_analyses(x)
  validate_tests(x)
  validate_sensitivities(x)
  validate_extensions(x)
  validate_regressions(x)
  validate_research_designs(x)
  validate_model_references(x)
  invisible(x)
}

#' Save and reopen a portable JSON bundle
#'
#' Files contain data only. Writes use a temporary file in the destination
#' directory and rename after validation. Existing files require `overwrite`.
#' Content identifiers detect accidental edits; they are not signatures or proof
#' of authorship. Only open bundles from sources you trust for scientific use.
#' @param x A local record.
#' @param path Path to a JSON bundle.
#' @param overwrite Whether to deliberately replace an existing bundle.
#' @return `write_record()` invisibly returns the path; `read_record()` returns
#'   a validated record without recomputing its results.
#' @export
write_record <- function(x, path, overwrite = FALSE) {
  validate_record(x)
  check_text(path, "path")
  if (!is.logical(overwrite) || length(overwrite) != 1 || is.na(overwrite)) {
    abort_suppose("{.arg overwrite} must be TRUE or FALSE.")
  }
  if (fs::file_exists(path) && !overwrite) {
    abort_suppose(
      "File {.path {path}} exists; set {.code overwrite = TRUE} to replace it.",
      "exists",
      path = path
    )
  }
  if (!fs::dir_exists(fs::path_dir(path))) {
    abort_suppose(
      "Destination directory does not exist: {.path {path}}.",
      "io",
      path = path
    )
  }
  tmp <- tempfile(pattern = ".suppose-", tmpdir = fs::path_dir(path))
  withr::defer(unlink(tmp))
  tryCatch(
    {
      writeLines(json_data(x, pretty = TRUE), tmp, useBytes = TRUE)
      read_record(tmp)
      if (fs::file_exists(path) && !overwrite) {
        abort_suppose(
          "Destination appeared during write; choose a new path.",
          "exists"
        )
      }
      fs::file_move(tmp, path)
    },
    error = function(e) {
      if (inherits(e, "suppose_error")) {
        stop(e)
      }
      abort_suppose(
        "Could not write bundle to {.path {path}}.",
        "io",
        parent = e,
        path = path
      )
    }
  )
  invisible(path)
}

#' @rdname write_record
#' @export
read_record <- function(path) {
  check_text(path, "path")
  if (!fs::file_exists(path)) {
    abort_suppose("Bundle not found: {.path {path}}.", "io", path = path)
  }
  x <- tryCatch(
    jsonlite::fromJSON(
      path,
      simplifyVector = TRUE,
      simplifyDataFrame = FALSE,
      simplifyMatrix = FALSE
    ),
    error = function(e) {
      abort_suppose(
        "Cannot read JSON bundle {.path {path}}.",
        "io",
        parent = e,
        path = path
      )
    }
  )
  validate_record(x)
  restore <- restore_record_types
  structure(restore(x), class = c("suppose_record", "list"))
}

restore_record_types <- function(z) {
  if (!is.list(z)) {
    return(z)
  }
  z <- lapply(z, restore_record_types)
  if (
    is.character(z$type) &&
      length(z$type) == 1L &&
      z$type %in%
        c(
          "suppose_claim",
          "suppose_model_reference",
          "suppose_judgment",
          "suppose_prior",
          "suppose_prediction",
          "suppose_acceptance",
          "suppose_proposal",
          "suppose_assistance",
          "suppose_observations",
          "suppose_evidence",
          "suppose_update",
          "suppose_update_entry",
          "suppose_analysis",
          "suppose_test_commitment",
          "suppose_test_assessment",
          "suppose_sensitivity",
          "suppose_sensitivity_entry",
          "suppose_extension_comparison",
          "suppose_model_extension",
          "suppose_form_draft",
          "suppose_predictors",
          "suppose_regression_spec",
          "suppose_regression",
          "suppose_regression_entry",
          "suppose_research_design",
          "suppose_research_design_entry"
        )
  ) {
    fields <- switch(
      z$type,
      suppose_claim = c("assumptions", "unresolved", "expectations"),
      suppose_judgment = c("observed", "issues"),
      suppose_analysis = "observation_ids",
      suppose_research_design = "recommended",
      suppose_form_draft = c(
        "provided_fields",
        "defaulted_fields",
        "preserved_fields"
      ),
      suppose_sensitivity = c("evidence_ids", "assessment_ids", "followup"),
      suppose_test_commitment = c(
        "basis_observation_ids",
        "context_observation_ids"
      ),
      suppose_test_assessment = c(
        "evidence_ids",
        "observation_ids",
        "issues",
        "missing_ids",
        "excluded_ids"
      ),
      suppose_observations = c("missing_ids", "repeated_ids"),
      character()
    )
    for (field in fields) {
      if (is.list(z[[field]]) && length(z[[field]]) == 0L) {
        z[[field]] <- character()
      }
    }
    class(z) <- c(z$type, "list")
  }
  z
}

#' @export
print.suppose_record <- function(x, ...) {
  validate_record(x)
  cli::cli_h2("{x$record_id}")
  for (i in seq_along(x$revisions)) {
    e <- x$revisions[[i]]
    status <- if (!is.null(e$acceptance)) {
      "accepted"
    } else if (!is.null(e$candidate)) {
      "proposed"
    } else {
      "draft"
    }
    cli::cli_text("Revision {i} ({status}): {e$reason}")
  }
  if (length(x$observations)) {
    cli::cli_h3("Attached measurements")
    for (a in x$observations) {
      d <- a$data
      cli::cli_text(
        "Revision {a$revision}: {length(d$rows)} rows from {d$source}; {length(d$missing_ids)} missing; use {d$role}, exposure {d$exposure}."
      )
    }
  }
  if (length(x$model_extensions)) {
    cli::cli_h3("Reviewed model alternatives")
    for (entry in x$model_extensions) {
      cli::cli_text(
        "{entry$comparison$settings$predictor}: {entry$choice}; {entry$reason}"
      )
    }
  }
  if (length(x$regressions)) {
    cli::cli_h3("Reviewed regressions")
    for (entry in x$regressions) {
      cli::cli_text("{entry$choice}: {entry$reason}")
      if (!is.null(entry$result$comparison)) {
        difference <- entry$result$comparison$extended_minus_baseline
        se <- entry$result$comparison$paired_se
        cli::cli_text(
          "Extended minus baseline LOO log score: {round(difference, 2)} (paired SE {round(se, 2)})."
        )
      }
    }
  }
  if (length(x$sensitivities)) {
    cli::cli_h3("Sensitivity analyses")
    for (entry in x$sensitivities) {
      cli::cli_text("{entry$reason}")
      for (question in entry$result$followup) {
        cli::cli_text("{question}")
      }
    }
  }
  if (length(x$commitments)) {
    cli::cli_h3("Prospective tests")
    for (test in x$commitments) {
      cli::cli_text(
        "Revision {test$revision}: {test$source}; deadline {test$horizon}."
      )
      results <- Filter(
        function(a) identical(a$commitment_id, test$id),
        x$assessments
      )
      for (a in results) {
        cli::cli_text("{a$assessed_at}: {a$status}")
      }
    }
  }
  c <- utils::tail(x$revisions, 1)[[1]]$claim
  cli::cli_h3("Current interpretation")
  cli::cli_text("{c$wording}")
  labels <- c(
    target = "Target",
    scope = "Scope",
    horizon = "Time horizon",
    units = "Units",
    expectations = "Expectations",
    assumptions = "Assumptions",
    unresolved = "Open questions"
  )
  for (nm in names(labels)) {
    if (length(c[[nm]])) {
      text <- paste(c[[nm]], collapse = "; ")
      cli::cli_text("{labels[[nm]]}: {text}")
    }
  }
  invisible(x)
}

merge_judgments <- function(fitted, additional) {
  if (!is.list(additional)) {
    abort_suppose("Supply judgments as a list.")
  }
  out <- c(fitted, additional)
  for (j in out) {
    check_seal(j, "suppose_judgment")
  }
  if (!length(out)) {
    return(list())
  }
  out[!duplicated(vapply(out, function(j) j$id, character(1)))]
}
