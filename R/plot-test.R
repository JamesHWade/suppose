#' Plot a frozen test prediction and its observed comparison
#' @param x A retained `suppose_test_commitment` from [commit_test()].
#' @param assessment Optional `suppose_test_assessment` for this exact commitment.
#'   Waiting or inconclusive results have no numerical comparison to plot.
#' @return An editable ggplot2 plot. The interval is the original prediction;
#'   it is not refitted using the assessment outcomes.
#' @export
plot_test <- function(x, assessment = NULL) {
  check_seal(x, "suppose_test_commitment")
  rlang::check_installed("ggplot2")
  if (!is.null(assessment)) {
    check_seal(assessment, "suppose_test_assessment")
    if (!identical(assessment$commitment_id, x$id)) {
      abort_suppose(
        "Assessment and frozen prediction references differ.",
        "revision"
      )
    }
  }
  p <- x$prediction
  data <- data.frame(
    quantity = "Frozen prediction",
    value = p$mean,
    lower = p$lower,
    upper = p$upper
  )
  if (!is.null(assessment$observed)) {
    data <- rbind(
      data,
      data.frame(
        quantity = "Observed difference",
        value = assessment$observed$difference,
        lower = NA_real_,
        upper = NA_real_
      )
    )
  }
  ggplot2::ggplot(data, ggplot2::aes(x = .data$value, y = .data$quantity)) +
    ggplot2::geom_segment(
      data = data[!is.na(data$lower), ],
      ggplot2::aes(x = .data$lower, xend = .data$upper, yend = .data$quantity),
      linewidth = 1.2,
      colour = "#245747"
    ) +
    ggplot2::geom_point(
      ggplot2::aes(shape = .data$quantity, colour = .data$quantity),
      size = 3
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "Frozen prediction" = "#245747",
        "Observed difference" = "#9a5429"
      )
    ) +
    ggplot2::scale_shape_manual(
      values = c("Frozen prediction" = 16, "Observed difference" = 18)
    ) +
    ggplot2::labs(
      title = "What was predicted before the outcomes?",
      subtitle = paste0(
        "Central ",
        format(100 * p$coverage),
        "% prediction interval\n",
        paste(p$planned_n, collapse = " and "),
        " planned measurements"
      ),
      x = paste0("Second group mean minus first (", p$units, ")"),
      y = NULL,
      caption = if (is.null(assessment)) {
        "A frozen prediction, not an assessment of truth."
      } else {
        test_status_label(assessment$status)
      },
      alt = test_prediction_text(x)
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "#faf9f5", colour = NA)
    )
}
