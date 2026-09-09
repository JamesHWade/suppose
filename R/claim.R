#' State a claim in your own words
#'
#' Claims can remain incomplete or qualitative. `NULL` means unknown;
#' `character()` explicitly records no assumptions or unresolved questions.
#' No causal identification or probability is inferred from the wording.
#' @param wording Original or revised statement.
#' @param author Person responsible for this statement.
#' @param target Precisely defined target quantity; `NULL` if unresolved.
#' @param units Outcome units; `NULL` if unresolved.
#' @param scope Population and protocol; `NULL` if unresolved.
#' @param horizon Relevant period; `NULL` if unresolved.
#' @param assumptions,unresolved Character vectors, or `NULL` if unknown.
#' @param expectations Qualitative or explicitly stated expectations in the user's words.
#' @param threshold Material improvement threshold; `NULL` if unresolved.
#' @return A content-identified `suppose_claim` list.
#' @export
#' @examples
#' claim("Higher cure temperature makes the material stronger.", "Scientist")
claim <- function(
  wording,
  author,
  target = NULL,
  units = NULL,
  scope = NULL,
  horizon = NULL,
  assumptions = NULL,
  unresolved = NULL,
  threshold = NULL,
  expectations = NULL
) {
  check_text(wording, "wording")
  check_text(author, "author")
  for (arg in c("target", "units", "scope", "horizon")) {
    check_text(get(arg), arg, TRUE)
  }
  for (arg in c("assumptions", "unresolved", "expectations")) {
    if (!is.null(get(arg))) check_strings(get(arg), arg)
  }
  if (!is.null(threshold)) {
    check_number(threshold, "threshold")
  }
  seal(
    list(
      wording = wording,
      original_wording = wording,
      author = author,
      target = target,
      units = units,
      scope = scope,
      horizon = horizon,
      assumptions = assumptions,
      unresolved = unresolved,
      threshold = threshold,
      expectations = expectations,
      parent_id = NULL,
      reason = NULL,
      created_at = now_utc()
    ),
    "suppose_claim"
  )
}

#' Revise a claim without replacing its original wording
#' @param x A claim.
#' @param author Person making the revision.
#' @param reason Why the meaning changed.
#' @param ... Named claim fields to change. See [claim()].
#' @return A new claim linked to its parent by content identifier.
#' @export
revise_claim <- function(x, author, reason, ...) {
  check_seal(x, "suppose_claim")
  check_text(reason, "reason")
  changes <- list(...)
  fields <- c(
    "wording",
    "target",
    "units",
    "scope",
    "horizon",
    "assumptions",
    "unresolved",
    "threshold",
    "expectations"
  )
  if (
    length(changes) &&
      (is.null(names(changes)) ||
        any(!nzchar(names(changes))) ||
        anyDuplicated(names(changes)) ||
        any(!names(changes) %in% fields))
  ) {
    abort_suppose(
      "Supply unique named claim fields to revise; see {.fn claim}."
    )
  }
  args <- stats::setNames(lapply(fields, function(nm) x[[nm]]), fields)
  args[names(changes)] <- changes
  out <- do.call(claim, c(args, list(author = author)))
  out$id <- NULL
  out$original_wording <- x$original_wording
  out$parent_id <- x$id
  out$reason <- reason
  seal(out, "suppose_claim")
}

#' @export
print.suppose_claim <- function(x, ...) {
  cli::cli_h2("Claim")
  cli::cli_text("{x$wording}")
  cli::cli_text("Author: {x$author}")
  cli::cli_text("Target: {if (is.null(x$target)) 'unresolved' else x$target}")
  invisible(x)
}
