#' Plot changes across a sensitivity analysis
#' @param x A result from [sensitivity_analysis()].
#' @param quantity Display the mean-difference estimate and central 90% interval,
#'   or the probability of exceeding the claim threshold.
#' @return An editable ggplot2 plot. Failed computations are omitted from the
#'   geometry and counted explicitly in the caption.
#' @export
plot_sensitivity <- function(x, quantity = c("estimate", "probability")) {
  check_seal(x, "suppose_sensitivity")
  rlang::check_installed("ggplot2")
  quantity <- match.arg(quantity)
  if (!quantity %in% x$quantities) {
    abort_suppose("Choose a quantity included in this sensitivity analysis.")
  }
  successful <- Filter(function(r) r$status == "completed", x$rows)
  data <- data.frame(
    component = character(),
    power = numeric(),
    value = numeric(),
    lower = numeric(),
    upper = numeric()
  )
  if (length(successful)) {
    data <- do.call(
      rbind,
      lapply(successful, function(r) {
        data.frame(
          component = if (r$component == "prior") {
            "Prior strength"
          } else {
            "Likelihood weight"
          },
          power = r$power,
          value = if (quantity == "estimate") {
            r$target$mean
          } else {
            r$target$probability_above
          },
          lower = r$target$lower,
          upper = r$target$upper
        )
      })
    )
  }
  baseline <- if (quantity == "estimate") {
    x$baseline$mean
  } else {
    x$baseline$probability_above
  }
  plot <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$power, y = .data$value)
  ) +
    ggplot2::geom_hline(
      yintercept = baseline,
      colour = "#888888",
      linetype = "dashed"
    ) +
    ggplot2::geom_vline(
      xintercept = 1,
      colour = "#aaaaaa",
      linetype = "dotted"
    ) +
    ggplot2::geom_point(colour = "#245747", size = 2.5) +
    ggplot2::scale_x_log10(breaks = x$powers) +
    ggplot2::labs(
      x = "Power (1 = original)",
      y = if (quantity == "estimate") {
        paste0("Mean difference (", x$units, ")")
      } else {
        paste0("P(difference > ", format(x$threshold), ")")
      },
      title = if (quantity == "estimate") {
        "How much does the estimate move?"
      } else {
        "How much does the probability move?"
      },
      subtitle = if (quantity == "estimate") {
        "Points: mean; bars: central 90% interval"
      } else {
        "Probability under each weighted model"
      },
      caption = paste0(
        length(x$rows) - length(successful),
        " failed computations omitted.\nOnly the selected power range is checked."
      ),
      alt = paste(
        "Sensitivity across",
        paste(x$components, collapse = " and "),
        "powers",
        paste(x$powers, collapse = ", "),
        ".",
        paste(x$followup, collapse = " ")
      )
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "#faf9f5", colour = NA)
    )
  if (length(successful)) {
    plot <- plot + ggplot2::facet_wrap(~component, ncol = 1)
  }
  if (quantity == "estimate") {
    plot <- plot +
      ggplot2::geom_linerange(
        ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
        colour = "#245747"
      )
  } else {
    plot <- plot + ggplot2::scale_y_continuous(limits = c(0, 1))
  }
  plot
}
