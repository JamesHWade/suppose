#' Inspect regression priors, predictions, checks and comparisons
#' @param x A result from [regression_prior()] or [fit_regression()].
#' @param view `prior`, `prediction`, `checks`, `residuals`, or `comparison`.
#'   A prior specification supports only `prior`.
#' @return A ggplot. Predictive intervals contain central 90% probability.
#' @export
plot_regression <- function(
  x,
  view = if (identical(x$type, "suppose_regression_spec")) {
    "prior"
  } else {
    "prediction"
  }
) {
  rlang::check_installed("ggplot2")
  view <- rlang::arg_match(
    view,
    c("prior", "prediction", "checks", "residuals", "comparison")
  )
  is_prior <- identical(x$type, "suppose_regression_spec")
  check_seal(
    x,
    if (is_prior) "suppose_regression_spec" else "suppose_regression"
  )
  if (is_prior && view != "prior") {
    abort_suppose(
      "Fit the reviewed specification before plotting fitted results."
    )
  }
  spec <- if (is_prior) x else x$spec
  if (view %in% c("prior", "prediction")) {
    predictions <- if (view == "prior") {
      spec$prior_predictions
    } else {
      lapply(x$fits, `[[`, "predictions")
    }
    data <- do.call(
      rbind,
      lapply(seq_along(predictions), function(k) {
        do.call(
          rbind,
          lapply(seq_along(predictions[[k]]), function(i) {
            p <- predictions[[k]][[i]]
            data.frame(
              model = spec$priors[[k]]$label,
              row = i,
              mean = p$mean,
              lower = p$outcome_lower,
              upper = p$outcome_upper,
              mean_lower = p$mean_lower,
              mean_upper = p$mean_upper,
              observed = if (view == "prior") {
                NA_real_
              } else {
                x$observed[[p$observation_id]]
              }
            )
          })
        )
      })
    )
    plot <- ggplot2::ggplot(data, ggplot2::aes(x = .data$row, y = .data$mean)) +
      ggplot2::geom_linerange(
        ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
        color = "#94aaa7",
        linewidth = 1.5
      ) +
      ggplot2::geom_linerange(
        ggplot2::aes(ymin = .data$mean_lower, ymax = .data$mean_upper),
        color = "#245b55",
        linewidth = 3
      ) +
      ggplot2::facet_wrap(~model, ncol = 1) +
      ggplot2::labs(
        x = "Measurement row (using its recorded predictor values)",
        y = paste("Outcome", spec$units),
        title = if (view == "prior") {
          "Review predictions before fitting"
        } else {
          "Predictions and observed outcomes"
        },
        subtitle = "Central 90% intervals: light = new outcome; dark = uncertain mean",
        caption = if (view == "prior") {
          "New regression assumptions; outcome values did not set these priors."
        } else {
          "Points are fitted data, not held-out validation. Measurement noise remains uncertain."
        }
      )
    if (view == "prediction") {
      plot <- plot +
        ggplot2::geom_point(ggplot2::aes(y = .data$observed), shape = 4)
    }
  } else if (view == "checks") {
    rows <- do.call(
      rbind,
      lapply(x$fits, function(f) {
        do.call(
          rbind,
          lapply(f$checks, function(c) {
            data.frame(
              model = f$label,
              statistic = c$statistic,
              value = c$replicated,
              observed = c$observed
            )
          })
        )
      })
    )
    lines <- unique(rows[c("model", "statistic", "observed")])
    plot <- ggplot2::ggplot(rows, ggplot2::aes(x = .data$value)) +
      ggplot2::geom_histogram(bins = 25, fill = "#94aaa7", color = "white") +
      ggplot2::geom_vline(
        data = lines,
        ggplot2::aes(xintercept = .data$observed),
        linetype = "dashed",
        color = "#9a4d26"
      ) +
      ggplot2::facet_wrap(~ model + statistic, scales = "free", ncol = 2) +
      ggplot2::labs(
        x = "Replicated discrepancy",
        y = "Replicates",
        title = "What does the fitted model fail to reproduce?",
        caption = "Dashed: observed discrepancy (median over parameter draws when parameter-dependent).\nReported tail areas compare paired observed and replicated discrepancies."
      )
  } else if (view == "residuals") {
    rows <- do.call(
      rbind,
      lapply(x$fits, function(f) {
        fitted <- vapply(f$predictions, `[[`, numeric(1), "mean")
        do.call(
          rbind,
          lapply(names(x$predictor_values), function(name) {
            data.frame(
              model = f$label,
              predictor = paste(name, spec$predictor_units[[name]]),
              value = x$predictor_values[[name]],
              residual = unlist(x$observed, use.names = FALSE) - fitted
            )
          })
        )
      })
    )
    plot <- ggplot2::ggplot(
      rows,
      ggplot2::aes(x = .data$value, y = .data$residual)
    ) +
      ggplot2::geom_hline(
        yintercept = 0,
        linetype = "dashed",
        color = "grey50"
      ) +
      ggplot2::geom_point(color = "#245b55") +
      ggplot2::facet_wrap(~ model + predictor, scales = "free_x", ncol = 2) +
      ggplot2::labs(
        x = "Recorded predictor value",
        y = paste("Observed minus fitted mean", spec$units),
        title = "Look for residual patterns, including omitted predictors",
        caption = "Uses fitted observations; residual patterns guide model criticism, not causal identification."
      )
  } else {
    if (is.null(x$comparison)) {
      abort_suppose("Fit an added predictor before comparing models.")
    }
    data <- data.frame(
      row = seq_along(x$comparison$pointwise),
      difference = unlist(x$comparison$pointwise, use.names = FALSE)
    )
    plot <- ggplot2::ggplot(
      data,
      ggplot2::aes(x = .data$row, y = .data$difference)
    ) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
      ggplot2::geom_point(color = "#245b55") +
      ggplot2::labs(
        x = "Held-out measurement row",
        y = "Extended minus baseline log predictive score",
        title = "Which held-out observations benefit from the added predictor?",
        subtitle = sprintf(
          "Total difference %.2f; approximate paired SE %.2f",
          x$comparison$extended_minus_baseline,
          x$comparison$paired_se
        ),
        caption = "Each prediction refits without that outcome. Fixed priors and transforms; exchangeable observations."
      )
  }
  plot +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}
