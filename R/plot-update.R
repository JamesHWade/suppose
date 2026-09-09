#' Compare prior, posterior, and predictive uncertainty
#' @param x A result from [update_prior()].
#' @param view `"target"` compares prior and posterior densities;
#'   `"intervals"` adds central 90% future-measurement intervals.
#' @return An editable ggplot2 plot.
#' @export
plot_update <- function(x, view = c("target", "intervals")) {
  check_seal(x, "suppose_update")
  rlang::check_installed("ggplot2")
  view <- match.arg(view)
  summaries <- list(
    Prior = x$prior,
    Posterior = x$target,
    `Future measurements` = x$predictive
  )
  theme <- ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "#faf9f5", colour = NA),
      panel.grid.minor = ggplot2::element_blank()
    )
  if (view == "intervals") {
    rlang::check_installed("ggdist")
    data <- do.call(
      rbind,
      lapply(names(summaries), function(label) {
        s <- summaries[[label]]
        data.frame(
          quantity = label,
          center = s$mean,
          lower = s$lower,
          upper = s$upper
        )
      })
    )
    data$quantity <- factor(data$quantity, levels = rev(names(summaries)))
    return(
      ggplot2::ggplot(
        data,
        ggplot2::aes(
          x = .data$center,
          y = .data$quantity,
          xmin = .data$lower,
          xmax = .data$upper
        )
      ) +
        ggdist::geom_pointinterval(colour = "#245747") +
        ggplot2::geom_vline(
          xintercept = x$threshold,
          linetype = 2,
          colour = "#9a5429"
        ) +
        ggplot2::labs(
          title = "Beliefs and future measurements",
          subtitle = "Central 90% intervals",
          x = paste0("Difference (", x$units, ")"),
          y = NULL,
          alt = update_summary_text(x)
        ) +
        theme
    )
  }
  summaries <- summaries[1:2]
  limits <- range(
    vapply(summaries, function(s) s$mean - 4 * s$sd, numeric(1)),
    vapply(summaries, function(s) s$mean + 4 * s$sd, numeric(1)),
    x$threshold
  )
  if (diff(limits) == 0) {
    limits <- limits + c(-1, 1)
  }
  grid <- seq(limits[1], limits[2], length.out = 600)
  curves <- do.call(
    rbind,
    lapply(names(summaries), function(label) {
      s <- summaries[[label]]
      data.frame(
        value = grid,
        density = if (s$sd == 0) 0 else stats::dnorm(grid, s$mean, s$sd),
        quantity = label,
        point_mass = s$sd == 0
      )
    })
  )
  p <- ggplot2::ggplot(
    curves[!curves$point_mass, ],
    ggplot2::aes(
      x = .data$value,
      y = .data$density,
      colour = .data$quantity,
      linetype = .data$quantity
    )
  ) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_vline(
      xintercept = x$threshold,
      colour = "#9a5429",
      linetype = 2
    ) +
    ggplot2::scale_colour_manual(
      values = c(Prior = "#697d76", Posterior = "#245747")
    ) +
    ggplot2::labs(
      title = "What changed after the measurements?",
      x = paste0("Mean difference (", x$units, ")"),
      y = "Density",
      caption = "Conditional on the stated prior and measurement model.\nBrown dashed line: threshold.",
      alt = update_summary_text(x)
    ) +
    theme
  for (label in names(summaries)) {
    if (summaries[[label]]$sd == 0) {
      p <- p +
        ggplot2::geom_vline(
          xintercept = summaries[[label]]$mean,
          colour = if (label == "Prior") "#697d76" else "#245747"
        )
    }
  }
  p
}

update_summary_text <- function(x) {
  sprintf(
    "Prior mean difference %.2f, central 90%% interval %.2f to %.2f %s. Posterior mean difference %.2f, central 90%% interval %.2f to %.2f %s. Probability of exceeding %s %s changes from %.1f%% to %.1f%%, conditional on the prior and measurement model.",
    x$prior$mean,
    x$prior$lower,
    x$prior$upper,
    x$units,
    x$target$mean,
    x$target$lower,
    x$target$upper,
    x$units,
    x$threshold,
    x$units,
    100 * x$prior$probability_above,
    100 * x$target$probability_above
  )
}

update_inventory <- function(x) {
  lapply(x$updates, function(a) {
    list(
      id = a$result$id,
      revision = a$revision,
      reason = a$reason,
      prior_id = a$result$prior_id,
      observations = a$result$observation_ids,
      summary = update_summary_text(a$result),
      diagnostics = a$result$diagnostics
    )
  })
}
