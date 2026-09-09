#' Fit a bounded two-condition normal prior
#'
#' Fits normal quantiles by least squares separately at two conditions. The
#' correlation of uncertain means and known batch standard deviations are
#' explicit assumptions, not quantities identified by marginal judgments.
#' Normal support permits negative values; negative-mass diagnostics are
#' returned. The disputed improvement is never imposed as a restriction.
#' @param x A complete claim with target, units, scope, and threshold.
#' @param judgments A list of two quantile judgments about uncertain means.
#' @param correlation Prior correlation between the two means, between -1 and 1.
#' @param batch_sd Known batch measurement standard deviations, one per condition.
#' @param tolerance Maximum absolute quantile mismatch in outcome units.
#' @return A proposed `suppose_prior` with parameters and fitting diagnostics.
#' @export
fit_prior <- function(x, judgments, correlation, batch_sd, tolerance = 0.1) {
  check_seal(x, "suppose_claim")
  for (arg in c("target", "units", "scope")) {
    if (is.null(x[[arg]])) {
      abort_suppose(
        "Resolve claim {.field {arg}} before fitting.",
        "incomplete",
        field = arg
      )
    }
  }
  if (is.null(x$threshold)) {
    abort_suppose(
      "Resolve the claim's material threshold before fitting.",
      "incomplete"
    )
  }
  check_number(correlation, "correlation", -1, 1)
  check_number(tolerance, "tolerance", 0)
  if (
    !is.numeric(batch_sd) ||
      length(batch_sd) != 2L ||
      any(!is.finite(batch_sd)) ||
      any(batch_sd < 0)
  ) {
    abort_suppose(
      "{.arg batch_sd} must give two finite, nonnegative standard deviations."
    )
  }
  if (!is.list(judgments) || length(judgments) != 2L) {
    abort_suppose("Supply two mean-quantile judgments.")
  }
  for (j in judgments) {
    check_seal(j, "suppose_judgment")
    if (!identical(j$units, x$units)) {
      abort_suppose(
        "Judgment units must match claim units ({x$units}).",
        "units"
      )
    }
    if (j$kind != "quantile" || j$quantity != "mean" || length(j$issues)) {
      abort_suppose(
        c(
          "Clarify this judgment before fitting.",
          "i" = "{j$answer}",
          "i" = "Supply increasing quantiles of an uncertain mean, with explicit probabilities."
        ),
        "judgment"
      )
    }
  }
  if (
    judgments[[1]]$condition >= judgments[[2]]$condition ||
      judgments[[1]]$condition_units != judgments[[2]]$condition_units
  ) {
    abort_suppose(
      "Supply conditions in increasing order with matching condition units.",
      "condition"
    )
  }
  fits <- lapply(judgments, function(j) {
    z <- stats::qnorm(j$probabilities)
    b <- stats::lm.fit(cbind(1, z), j$values)$coefficients
    if (any(!is.finite(b)) || b[2] <= 0) {
      abort_suppose("Normal quantile fit failed; review the inputs.", "fit")
    }
    list(
      mean = unname(b[1]),
      sd = unname(b[2]),
      implied = unname(b[1] + b[2] * z),
      residual = unname(b[1] + b[2] * z - j$values)
    )
  })
  max_error <- max(abs(unlist(lapply(fits, `[[`, "residual"))))
  mu <- vapply(fits, `[[`, numeric(1), "mean")
  sigma <- vapply(fits, `[[`, numeric(1), "sd")
  seal(
    list(
      claim = x,
      judgments = judgments,
      means = mu,
      mean_sd = sigma,
      conditions = vapply(judgments, `[[`, numeric(1), "condition"),
      condition_units = judgments[[1]]$condition_units,
      correlation = correlation,
      batch_sd = batch_sd,
      fits = fits,
      max_error = max_error,
      tolerance = tolerance,
      fit_ok = max_error <= tolerance,
      negative_mean_probability = stats::pnorm(0, mu, sigma),
      negative_batch_probability = stats::pnorm(
        0,
        mu,
        sqrt(sigma^2 + batch_sd^2)
      ),
      method = "normal-quantile-ls-v1",
      status = "proposed",
      assumptions = c(
        "Jointly normal uncertain means; unbounded support.",
        "Known batch SDs; independent normal measurement noise across conditions.",
        "Correlation is supplied, not identified by marginal quantiles.",
        "Two conditions do not establish monotonicity or a causal effect."
      ),
      created_at = now_utc()
    ),
    "suppose_prior"
  )
}

#' @export
print.suppose_prior <- function(x, ...) {
  cli::cli_h2("Proposed normal prior")
  cli::cli_text("Mean strengths: {round(x$means, 3)} {x$claim$units}")
  cli::cli_text(
    "Prior correlation: {x$correlation}; maximum quantile mismatch: {signif(x$max_error, 3)} {x$claim$units}"
  )
  cli::cli_text("Matches elicited summaries within tolerance: {x$fit_ok}")
  cli::cli_text("Elicitation fit is not empirical validation.")
  invisible(x)
}
