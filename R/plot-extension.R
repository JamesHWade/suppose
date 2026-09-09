#' Plot aligned predictions before and after adding a predictor
#' @param x A result from [compare_extension()].
#' @param quantity Plot observable `outcome` predictions or uncertain `mean`s.
#' @return An editable ggplot2 chart. Ribbons are central 90% intervals;
#'   predictions outside the original anchors require the stated extrapolation.
#' @export
plot_extension <- function(x, quantity = c("outcome", "mean")) {
  check_seal(x, "suppose_extension_comparison")
  quantity <- match.arg(quantity)
  rlang::check_installed("ggplot2")
  d <- do.call(
    rbind,
    lapply(x$rows, function(r) {
      data.frame(
        model = r$model,
        condition = r$condition,
        value = r$predictor_value,
        mean = r$mean,
        lower = r[[paste0(quantity, "_lower")]],
        upper = r[[paste0(quantity, "_upper")]]
      )
    })
  )
  d$panel <- paste(
    x$settings$predictor,
    "=",
    format(d$value),
    x$settings$predictor_units
  )
  ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$condition,
      y = .data$mean,
      colour = .data$model,
      linetype = .data$model
    )
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$lower, ymax = .data$upper, fill = .data$model),
      alpha = 0.12,
      colour = NA,
      show.legend = FALSE
    ) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_vline(
      xintercept = x$anchors,
      colour = "#999999",
      linetype = "dotted"
    ) +
    ggplot2::facet_wrap(~panel, ncol = 1) +
    ggplot2::scale_colour_manual(
      values = c(
        original = "#555555",
        unscaled = "#a05529",
        scaled = "#245747"
      ),
      breaks = c("original", "unscaled", "scaled"),
      labels = c("Reference", "Unscaled", "Scaled")
    ) +
    ggplot2::scale_fill_manual(
      values = c(original = "#555555", unscaled = "#a05529", scaled = "#245747")
    ) +
    ggplot2::scale_linetype_manual(
      values = c(original = "dotted", unscaled = "dashed", scaled = "solid"),
      breaks = c("original", "unscaled", "scaled"),
      labels = c("Reference", "Unscaled", "Scaled")
    ) +
    ggplot2::labs(
      title = "What changes when the model grows?",
      subtitle = "Central 90% intervals under stated assumptions",
      x = x$condition_units,
      y = paste(
        if (quantity == "outcome") "Outcome" else "Mean",
        paste0("(", x$units, ")")
      ),
      colour = NULL,
      linetype = NULL,
      caption = "Dotted vertical lines: elicited anchors.\nBeyond them: assumed extrapolation.",
      alt = paste(
        "Comparison of original, unscaled and scaled predictions for",
        x$settings$predictor,
        ".",
        x$matched_contrast$explanation
      )
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "#faf9f5", colour = NA)
    )
}
