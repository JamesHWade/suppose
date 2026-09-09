#' Run the illustrative strength elicitation
#'
#' All judgments are invented. The first candidate uses independent uncertain
#' means; the correction changes their correlation to 0.8 while retaining the
#' same marginal intervals. Both candidates and predictions are preserved.
#' @param seed Explicit simulation seed.
#' @param accept Whether to record illustrative acceptance by the demo scientist.
#' @return A local record with a draft and two candidate revisions.
#' @export
#' @examples
#' x <- suppose_example()
#' x
#' print(structure(x$revisions[[3]]$prediction, class = "suppose_prediction"))
suppose_example <- function(seed = 47L, accept = FALSE) {
  if (!is.logical(accept) || length(accept) != 1 || is.na(accept)) {
    abort_suppose("{.arg accept} must be TRUE or FALSE.")
  }
  c <- claim(
    "Higher cure temperature makes the material stronger.",
    "Demo scientist",
    target = "Mean batch strength at 160 degC minus mean batch strength at 140 degC",
    units = "MPa",
    scope = "Formulation F; protocol P; fixed cure duration; independently prepared batches",
    threshold = 5,
    assumptions = "Comparable preparation and measurement protocols",
    unresolved = "A causal interpretation needs a justified intervention protocol."
  )
  js <- list(
    judgment(
      140,
      c(45, 55),
      c(.05, .95),
      units = "MPa",
      author = "Demo scientist",
      answer = "90% probability the population mean is between 45 and 55 MPa",
      source = "Invented tutorial judgments",
      observed = character()
    ),
    judgment(
      160,
      c(51, 65),
      c(.05, .95),
      units = "MPa",
      author = "Demo scientist",
      answer = "90% probability the population mean is between 51 and 65 MPa",
      source = "Invented tutorial judgments",
      observed = character()
    )
  )
  p1 <- fit_prior(c, js, correlation = 0, batch_sd = c(3, 3))
  p2 <- fit_prior(c, js, correlation = .8, batch_sd = c(3, 3))
  out <- elicitation_record(c, "Cure temperature and strength") |>
    record_revision(
      c,
      p1,
      predict_prior(p1, seed = seed),
      reason = "Inspect independent mean uncertainty"
    ) |>
    record_revision(
      c,
      p2,
      predict_prior(p2, seed = seed),
      reason = "Shared uncertainty may move both means together"
    )
  if (accept) {
    out <- accept_revision(
      out,
      "Demo scientist",
      "Illustrative review: correlated means express the intended judgment.",
      "Collect independently prepared batches under a randomized temperature protocol; inspect both mean differences and batch variation."
    )
  }
  out
}
