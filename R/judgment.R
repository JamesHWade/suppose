#' Record the meaning and provenance of an elicited judgment
#'
#' A range without probabilities is retained as a range, never fitted as a
#' probability interval. The first fitting method supports quantiles of means.
#' @param condition Numeric condition (temperature in the example).
#' @param values Numeric answers, or `NULL` for qualitative answers.
#' @param probabilities Explicit cumulative probabilities, or `NULL`.
#' @param kind One of `quantile`, `range`, `comparison`, or `qualitative`.
#' @param quantity One of `mean`, `batch`, `specimen`, `contrast`, `shape`.
#' @param units Outcome units.
#' @param author,answer,rationale,source Attribution and original answer.
#' @param observed Information already seen, or `NULL` if unknown.
#' @param condition_units Condition units.
#' @param reference_condition Optional second condition. For comparisons the answer
#'   describes the first condition relative to this reference. For shape judgments
#'   the two conditions delimit the region described in the original answer.
#'   No probability or functional form is inferred from qualitative wording.
#' @return A `suppose_judgment`, including unresolved issues.
#' @export
#' @examples
#' judgment(140, c(45, 55), c(.05, .95), units = "MPa", author = "Scientist",
#'   answer = "90% probability the mean is between 45 and 55 MPa")
judgment <- function(
  condition,
  values = NULL,
  probabilities = NULL,
  kind = c("quantile", "range", "qualitative", "comparison"),
  quantity = c("mean", "batch", "specimen", "contrast", "shape"),
  units,
  author,
  answer,
  rationale = NULL,
  source = NULL,
  observed = NULL,
  condition_units = "degC",
  reference_condition = NULL
) {
  kind <- rlang::arg_match(kind)
  quantity <- rlang::arg_match(quantity)
  check_number(condition, "condition")
  for (arg in c("units", "author", "answer", "condition_units")) {
    check_text(get(arg), arg)
  }
  for (arg in c("rationale", "source")) {
    check_text(get(arg), arg, TRUE)
  }
  if (!is.null(observed)) {
    check_strings(observed, "observed")
  }
  if (
    !is.null(values) &&
      (!is.numeric(values) || !length(values) || any(!is.finite(values)))
  ) {
    abort_suppose("{.arg values} must contain finite numbers, or be NULL.")
  }
  if (
    !is.null(probabilities) &&
      (!is.numeric(probabilities) ||
        any(!is.finite(probabilities)) ||
        length(probabilities) != length(values) ||
        any(probabilities <= 0 | probabilities >= 1) ||
        anyDuplicated(probabilities))
  ) {
    abort_suppose(
      "Use distinct {.arg probabilities} strictly between 0 and 1, one per value.",
      "probability"
    )
  }
  if (!is.null(reference_condition)) {
    check_number(reference_condition, "reference_condition")
  }
  issues <- character()
  if (kind == "comparison") {
    if (is.null(reference_condition)) {
      issues <- c(
        issues,
        "Identify the reference condition for this comparison."
      )
    }
    issues <- c(
      issues,
      "Comparison retained without numerical fitting; no probability is inferred."
    )
  }
  if (kind == "quantile") {
    if (is.null(probabilities) || length(values) < 2L) {
      issues <- c(
        issues,
        "At least two values and explicit probabilities are needed."
      )
    } else if (any(diff(values[order(probabilities)]) <= 0)) {
      issues <- c(issues, "Values must increase with cumulative probability.")
    }
  }
  if (kind == "range") {
    issues <- c(
      issues,
      "Range has no probability interpretation; clarify before fitting."
    )
  }
  if (kind == "qualitative") {
    issues <- c(
      issues,
      "Qualitative judgment retained without numerical fitting."
    )
  }
  fields <- list(
    condition = condition,
    condition_units = condition_units,
    values = values,
    probabilities = probabilities,
    kind = kind,
    quantity = quantity,
    units = units,
    author = author,
    answer = answer,
    rationale = rationale,
    source = source,
    observed = observed,
    issues = issues,
    created_at = now_utc()
  )
  if (!is.null(reference_condition)) {
    fields$reference_condition <- reference_condition
  }
  seal(fields, "suppose_judgment")
}
