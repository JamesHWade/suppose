#' Link numeric predictors to retained measurements
#'
#' Predictor rows are matched by measurement ID, never by row position. This
#' retains covariate provenance without replacing the original outcome evidence.
#' All measurements in the selected evidence must be represented exactly once.
#' @param x A record with retained observations.
#' @param evidence_id The exact retained observation attachment ID.
#' @param data A data frame or CSV with `observation_id` and one or two finite
#'   numeric predictor columns. Missing predictors are not silently dropped.
#' @param units Named character vector of predictor units, matching the columns.
#' @param source Source identifier for the predictor measurements.
#' @param author Person declaring the predictor provenance.
#' @return A sealed predictor dataset for [record_predictors()].
#' @export
regression_predictors <- function(x, evidence_id, data, units, source, author) {
  validate_record(x)
  e <- regression_evidence(x, evidence_id)
  check_text(source, "source")
  check_text(author, "author")
  file_hash <- NULL
  if (is.character(data) && length(data) == 1L) {
    if (!fs::file_exists(data)) {
      abort_suppose("Predictor CSV not found.", "io")
    }
    file_hash <- digest::digest(file = data, algo = "sha256")
    data <- utils::read.csv(
      data,
      check.names = FALSE,
      colClasses = c(observation_id = "character")
    )
  }
  fields <- setdiff(names(data), "observation_id")
  if (
    !is.data.frame(data) ||
      anyDuplicated(names(data)) ||
      !"observation_id" %in% names(data) ||
      !length(fields) ||
      length(fields) > 2L ||
      !all(grepl("^[A-Za-z][A-Za-z0-9_]*$", fields)) ||
      "intercept" %in% fields
  ) {
    abort_suppose(
      "Supply observation_id and one or two named numeric predictors; use letters, digits and underscores, excluding intercept."
    )
  }
  check_strings(data$observation_id, "observation_id")
  ids <- vapply(e$data$rows, `[[`, character(1), "observation_id")
  if (
    anyDuplicated(data$observation_id) || !setequal(data$observation_id, ids)
  ) {
    abort_suppose(
      "Predictor IDs must match every measurement in the selected evidence exactly once.",
      "identity"
    )
  }
  check_strings(units, "units")
  if (
    is.null(names(units)) ||
      anyDuplicated(names(units)) ||
      !setequal(names(units), fields)
  ) {
    abort_suppose("Name one unit for each predictor column.", "units")
  }
  for (field in fields) {
    if (
      !is.numeric(data[[field]]) ||
        !all(is.finite(data[[field]])) ||
        length(unique(data[[field]])) < 2L
    ) {
      abort_suppose(
        "Predictor {.val {field}} must contain finite numbers and vary across measurements."
      )
    }
  }
  data <- data[
    match(ids, data$observation_id),
    c("observation_id", fields),
    drop = FALSE
  ]
  seal(
    list(
      record_id = x$record_id,
      evidence_id = e$id,
      claim_id = e$claim_id,
      revision = e$revision,
      source = source,
      author = author,
      file_hash = file_hash,
      units = as.list(units[fields]),
      rows = lapply(seq_len(nrow(data)), function(i) {
        as.list(data[i, , drop = FALSE])
      }),
      created_at = now_utc()
    ),
    "suppose_predictors"
  )
}

#' Retain a reviewed predictor dataset
#' @param x A record.
#' @param predictors Result from [regression_predictors()].
#' @return A record retaining the predictor measurements and original references.
#' @export
record_predictors <- function(x, predictors) {
  validate_record(x)
  check_seal(predictors, "suppose_predictors")
  e <- regression_evidence(x, predictors$evidence_id)
  if (
    !identical(predictors$record_id, x$record_id) ||
      !identical(predictors$claim_id, e$claim_id) ||
      predictors$revision != e$revision
  ) {
    abort_suppose(
      "Predictors belong to a different record or evidence revision.",
      "revision"
    )
  }
  if (predictors$id %in% vapply(x$predictors, `[[`, character(1), "id")) {
    abort_suppose("These predictors are already retained.", "duplicate")
  }
  x$predictors <- c(x$predictors, list(predictors))
  x$schema_version <- max(x$schema_version, 10L)
  validate_record(x)
  x
}

regression_evidence <- function(x, id) {
  check_text(id, "evidence_id")
  found <- Filter(function(e) identical(e$id, id), x$observations)
  if (length(found) != 1L) {
    abort_suppose("Select one retained observation attachment.", "reference")
  }
  found[[1]]
}

regression_dataset <- function(x, design_id) {
  check_text(design_id, "design_id")
  found <- Filter(function(d) identical(d$id, design_id), x$predictors)
  if (length(found) != 1L) {
    abort_suppose("Select a retained predictor dataset.", "reference")
  }
  d <- found[[1]]
  e <- regression_evidence(x, d$evidence_id)
  if (
    e$revision != length(x$revisions) ||
      !identical(e$claim_id, utils::tail(x$revisions, 1)[[1]]$claim$id)
  ) {
    abort_suppose(
      "These measurements belong to an earlier claim revision.",
      "revision"
    )
  }
  if (
    e$data$role != "update" || !e$data$exposure %in% c("unseen", "explored")
  ) {
    abort_suppose(
      "Regression requires update-designated observations with declared exposure; assessment or prior-used outcomes cannot be fitted.",
      "exposure"
    )
  }
  if (
    length(e$data$rows) < 6L ||
      length(e$data$rows) > 500L ||
      any(vapply(e$data$rows, function(r) is.null(r$converted), logical(1)))
  ) {
    abort_suppose(
      "Use 6 to 500 complete outcome measurements; missing rows are not silently removed."
    )
  }
  ids <- vapply(e$data$rows, `[[`, character(1), "observation_id")
  predictor_ids <- vapply(d$rows, `[[`, character(1), "observation_id")
  if (anyDuplicated(predictor_ids) || !setequal(ids, predictor_ids)) {
    abort_suppose("Predictor and outcome measurement IDs disagree.", "identity")
  }
  rows <- d$rows[match(ids, predictor_ids)]
  list(
    design = d,
    evidence = e,
    ids = ids,
    y = vapply(e$data$rows, `[[`, numeric(1), "converted"),
    predictors = lapply(names(d$units), function(n) {
      vapply(rows, `[[`, numeric(1), n)
    }) |>
      stats::setNames(names(d$units))
  )
}

validate_regressions <- function(x) {
  for (field in c("predictors", "regressions")) {
    if (
      !is.null(x[[field]]) && (x$schema_version < 10L || !is.list(x[[field]]))
    ) {
      abort_suppose("Invalid regression collection.", "record")
    }
  }
  for (d in x$predictors) {
    check_seal(d, "suppose_predictors")
    e <- regression_evidence(x, d$evidence_id)
    if (
      !identical(d$record_id, x$record_id) ||
        !identical(d$claim_id, e$claim_id) ||
        d$revision != e$revision
    ) {
      abort_suppose("Predictor references disagree.", "reference")
    }
  }
  for (entry in x$regressions) {
    check_seal(entry, "suppose_regression_entry")
    result <- entry$result
    check_seal(result, "suppose_regression")
    check_seal(result$spec, "suppose_regression_spec")
    if (
      !result$spec$design_id %in%
        vapply(x$predictors, `[[`, character(1), "id") ||
        !identical(result$spec$record_id, x$record_id)
    ) {
      abort_suppose("Regression references disagree.", "reference")
    }
    if (!is.null(entry$form_draft)) {
      check_seal(entry$form_draft, "suppose_form_draft")
    }
  }
  invisible(x)
}
