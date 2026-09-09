#' Visualize a prior and its predictive consequences
#'
#' Returns an editable ggplot2 plot, or a patchwork composition for the overview.
#' Densities and intervals use analytic normal summaries. These plots describe
#' elicited beliefs, not evidence from observations. The interval view uses ggdist.
#' @param x A fitted `suppose_prior` from [fit_prior()].
#' @param prediction Optional matching result from [predict_prior()]. If omitted,
#'   the analytic summaries are calculated with the default seed; RNG state is
#'   preserved.
#' @param view One of `"overview"`, `"means"`, `"contrast"`, or `"intervals"`.
#' @param interactive Return a Plotly widget with hover and zoom controls.
#' @return A ggplot2 object, a patchwork overview, or an interactive Plotly widget.
#' @importFrom rlang .data
#' @export
#' @examples
#' record <- suppose_example()
#' prior <- record$revisions[[3]]$candidate
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_prior(prior, view = "means")
#' }
plot_prior <- function(
  x,
  prediction = NULL,
  view = c("overview", "means", "contrast", "intervals"),
  interactive = FALSE
) {
  check_seal(x, "suppose_prior")
  prediction <- prediction %||% predict_prior(x, n = 2L)
  check_seal(prediction, "suppose_prediction")
  if (!identical(prediction$prior_id, x$id)) {
    abort_suppose("The prediction must belong to this prior.", "prediction")
  }
  visual <- inquiry_prior_visual(list(
    candidate = x,
    prediction = prediction,
    claim = x$claim
  ))
  view <- match.arg(view)
  if (
    !is.logical(interactive) || length(interactive) != 1L || is.na(interactive)
  ) {
    abort_suppose("interactive must be TRUE or FALSE.")
  }
  if (interactive) prior_plotly(visual, view) else prior_ggplot(visual, view)
}

prior_ggplot <- function(x, view) {
  rlang::check_installed("ggplot2")
  theme <- ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#fbf8ff", colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", colour = "#633b83"),
      plot.caption = ggplot2::element_text(hjust = 0)
    )
  colors <- c("#633b83", "#b74d08")
  d <- x$summary$mean_difference
  b <- x$summary$batch_difference
  if (view == "intervals") {
    rlang::check_installed("ggdist")
    data <- data.frame(
      quantity = c("Mean difference", "Future measurements"),
      center = c(d$mean, b$mean),
      lower = c(d$lower, b$lower),
      upper = c(d$upper, b$upper)
    )
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
        ggdist::geom_pointinterval(colour = colors[1]) +
        ggplot2::geom_vline(
          xintercept = x$threshold,
          colour = colors[2],
          linetype = 2
        ) +
        ggplot2::labs(
          title = "How much uncertainty?",
          subtitle = "Central 90% intervals; dashed line is the threshold",
          x = paste0("Difference (", x$units, ")"),
          y = NULL,
          alt = inquiry_prior_alt(x)
        ) +
        theme
    )
  }
  if (view %in% c("means", "overview")) {
    limits <- range(x$means + rep(c(-3.5, 3.5), each = 2) * x$mean_sd)
    grid <- seq(limits[1], limits[2], length.out = 600)
    data <- do.call(
      rbind,
      lapply(seq_len(2), function(i) {
        bounds <- stats::qnorm(c(0.05, 0.95), x$means[i], x$mean_sd[i])
        data.frame(
          value = grid,
          density = stats::dnorm(grid, x$means[i], x$mean_sd[i]),
          condition = paste(x$conditions[i], x$condition_units),
          central = grid >= bounds[1] & grid <= bounds[2]
        )
      })
    )
    means <- ggplot2::ggplot(
      data,
      ggplot2::aes(
        x = .data$value,
        y = .data$density,
        colour = .data$condition,
        linetype = .data$condition
      )
    ) +
      ggplot2::geom_area(
        data = data[data$central, ],
        ggplot2::aes(fill = .data$condition),
        position = "identity",
        alpha = 0.15,
        colour = NA,
        show.legend = FALSE
      ) +
      ggplot2::geom_line(linewidth = 0.8) +
      ggplot2::scale_colour_manual(values = colors) +
      ggplot2::scale_fill_manual(values = colors) +
      ggplot2::labs(
        title = "Your prior beliefs",
        subtitle = "Central 90% of each prior shaded",
        x = paste0("Population mean (", x$units, ")"),
        y = "Density",
        alt = inquiry_prior_alt(x)
      ) +
      theme
    if (view == "means") return(means)
  }
  spread <- max(d$sd, b$sd, 1e-8)
  limits <- range(d$mean + c(-3.5, 3.5) * spread, x$threshold)
  if (diff(limits) < 1e-6) {
    limits <- d$mean + c(-1, 1)
  }
  grid <- seq(limits[1], limits[2], length.out = 600)
  data <- do.call(
    rbind,
    lapply(c("Mean difference", "Future measurements"), function(label) {
      s <- if (label == "Mean difference") d else b
      data.frame(
        value = grid,
        density = if (s$sd == 0) 0 else stats::dnorm(grid, s$mean, s$sd),
        quantity = label,
        point_mass = s$sd == 0
      )
    })
  )
  contrast <- ggplot2::ggplot(
    data[!data$point_mass, ],
    ggplot2::aes(
      x = .data$value,
      y = .data$density,
      colour = .data$quantity,
      linetype = .data$quantity
    )
  ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_vline(
      xintercept = x$threshold,
      colour = colors[2],
      linetype = 2
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "Mean difference" = colors[1],
        "Future measurements" = "#8d719e"
      )
    ) +
    ggplot2::scale_linetype_manual(
      values = c("Mean difference" = 1, "Future measurements" = 3)
    ) +
    ggplot2::labs(
      title = "What those beliefs imply",
      subtitle = sprintf(
        "P(mean difference > %s %s) = %0.1f%%",
        x$threshold,
        x$units,
        100 * d$probability_above
      ),
      x = paste0(
        "Difference: ",
        x$conditions[2],
        " minus ",
        x$conditions[1],
        " (",
        x$units,
        ")"
      ),
      y = "Density",
      caption = "Brown dashed line: threshold.\nElicited beliefs, not observations.",
      alt = inquiry_prior_alt(x)
    ) +
    theme
  point <- data.frame(
    value = c(d$mean, b$mean),
    quantity = c("Mean difference", "Future measurements"),
    sd = c(d$sd, b$sd)
  )
  if (any(point$sd == 0)) {
    contrast <- contrast +
      ggplot2::geom_vline(
        data = point[point$sd == 0, ],
        ggplot2::aes(
          xintercept = .data$value,
          colour = .data$quantity,
          linetype = .data$quantity
        ),
        linewidth = 1
      ) +
      ggplot2::labs(
        caption = "Vertical lines: point masses where uncertainty is zero.\nBrown dashed line: threshold."
      )
  }
  if (view == "contrast") {
    return(contrast)
  }
  rlang::check_installed("patchwork")
  patchwork::wrap_plots(means, contrast, ncol = 1)
}


prior_plotly <- function(x, view = "contrast") {
  rlang::check_installed("plotly")
  if (view == "intervals") {
    d <- x$summary$mean_difference
    b <- x$summary$batch_difference
    data <- data.frame(
      quantity = c("Mean difference", "Future measurements"),
      center = c(d$mean, b$mean),
      lower = c(d$lower, b$lower),
      upper = c(d$upper, b$upper)
    )
    p <- ggplot2::ggplot(
      data,
      ggplot2::aes(x = .data$center, y = .data$quantity)
    ) +
      ggplot2::geom_errorbar(
        ggplot2::aes(xmin = .data$lower, xmax = .data$upper),
        orientation = "y",
        width = 0.15
      ) +
      ggplot2::geom_point() +
      ggplot2::geom_vline(xintercept = x$threshold, linetype = 2) +
      ggplot2::labs(x = paste0("Difference (", x$units, ")"), y = NULL)
    return(plotly::ggplotly(p))
  }
  if (view == "overview") {
    return(plotly::subplot(
      prior_plotly(x, "means"),
      prior_plotly(x, "contrast"),
      nrows = 2,
      margin = 0.08
    ))
  }
  plotly::config(
    plotly::layout(
      plotly::ggplotly(prior_ggplot(x, view)),
      legend = list(
        title = list(text = ""),
        orientation = "h",
        x = 0,
        xanchor = "left",
        y = -0.28
      ),
      margin = list(l = 50, r = 10, t = 45, b = 110),
      title = list(
        text = if (view == "means") "Prior means" else "Prior consequences",
        x = 0.02,
        xanchor = "left",
        font = list(size = 15)
      ),
      xaxis = list(
        title = if (view == "means") {
          paste0("Population mean (", x$units, ")")
        } else {
          paste0("Difference (", x$units, ")")
        }
      )
    ),
    displaylogo = FALSE
  )
}
