prior_draw_index <- function(x, index) {
  n <- length(x$draws$mean_low)
  if (is.null(index) || length(index) != 1L || !is.finite(index)) {
    return(1L)
  }
  as.integer(max(1, min(n, index)))
}

prior_draw_values <- function(x, index) {
  index <- prior_draw_index(x, index)
  vapply(x$draws, function(values) values[[index]], numeric(1))
}

prior_draw_dots <- function(x) {
  do.call(
    rbind,
    lapply(c("mean_difference", "batch_difference"), function(key) {
      s <- x$summary[[key]]
      value <- s$mean + s$sd * stats::qnorm((seq_len(100) - 0.5) / 100)
      data.frame(
        value = value,
        quantity = if (key == "mean_difference") {
          "Mean difference"
        } else {
          "Future measurement difference"
        },
        above = value > x$threshold
      )
    })
  )
}

prior_draw_summary <- function(x, index) {
  d <- prior_draw_values(x, index)
  sprintf(
    "Realization %s of %s. At %s and %s %s, population means are %.2f and %.2f %s; future measurements are %.2f and %.2f %s. Second minus first: mean difference %.2f %s; measurement difference %.2f %s. Prior %s; seed %s.",
    prior_draw_index(x, index),
    length(x$draws$mean_low),
    x$conditions[1],
    x$conditions[2],
    x$condition_units,
    d[["mean_low"]],
    d[["mean_high"]],
    x$units,
    d[["batch_low"]],
    d[["batch_high"]],
    x$units,
    d[["mean_difference"]],
    x$units,
    d[["batch_difference"]],
    x$units,
    x$prior_id,
    x$seed
  )
}

prior_draw_probability <- function(x) {
  sprintf(
    "Exact prior probabilities of exceeding %s %s: mean difference %.1f%%; future measurement difference %.1f%%. These probabilities use the full analytic distributions, not the fraction of frames viewed. Differences are second condition minus first.",
    x$threshold,
    x$units,
    100 * x$summary$mean_difference$probability_above,
    100 * x$summary$batch_difference$probability_above
  )
}

prior_draw_plot <- function(x, index, view = "pair") {
  d <- prior_draw_values(x, index)
  theme <- ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "none",
      plot.background = ggplot2::element_rect(fill = "#fbf8ff", colour = NA),
      strip.text = ggplot2::element_text(face = "bold", colour = "#633b83")
    )
  if (view == "pair") {
    data <- data.frame(
      value = unname(d[c("mean_low", "mean_high", "batch_low", "batch_high")]),
      condition = factor(
        rep(paste(x$conditions, x$condition_units), 2),
        levels = rev(paste(x$conditions, x$condition_units))
      ),
      quantity = rep(c("Population means", "Future measurements"), each = 2)
    )
    limits <- range(unlist(x$draws[c(
      "mean_low",
      "mean_high",
      "batch_low",
      "batch_high"
    )]))
    return(
      ggplot2::ggplot(
        data,
        ggplot2::aes(x = .data$value, y = .data$condition)
      ) +
        ggplot2::geom_point(size = 4, colour = "#633b83") +
        ggplot2::facet_wrap(~quantity, ncol = 1) +
        ggplot2::coord_cartesian(xlim = limits) +
        ggplot2::labs(
          x = x$units,
          y = NULL,
          alt = prior_draw_summary(x, index)
        ) +
        theme
    )
  }
  dots <- prior_draw_dots(x)
  selected <- data.frame(
    value = unname(d[c("mean_difference", "batch_difference")]),
    quantity = c("Mean difference", "Future measurement difference")
  )
  limits <- range(
    dots$value,
    x$draws$mean_difference,
    x$draws$batch_difference,
    x$threshold
  )
  ggplot2::ggplot(dots, ggplot2::aes(x = .data$value, y = 0)) +
    ggdist::geom_dots(
      ggplot2::aes(fill = .data$above),
      side = "top",
      dotsize = 0.7,
      colour = NA
    ) +
    ggplot2::geom_vline(
      xintercept = x$threshold,
      linetype = 2,
      colour = "#b74d08"
    ) +
    ggplot2::geom_point(
      data = selected,
      shape = 18,
      size = 4,
      colour = "#17121c"
    ) +
    ggplot2::facet_wrap(~quantity, ncol = 1) +
    ggplot2::scale_fill_manual(
      values = c("FALSE" = "#aa94bc", "TRUE" = "#633b83")
    ) +
    ggplot2::scale_y_continuous(breaks = NULL) +
    ggplot2::coord_cartesian(xlim = limits) +
    ggplot2::labs(
      x = paste0("Difference (", x$units, ")"),
      y = NULL,
      alt = paste(
        prior_draw_probability(x),
        "Each dot represents one percent. Black diamonds show the selected realization."
      )
    ) +
    theme
}

bind_prior_draws <- function(output, id, visual, session) {
  input <- session$input
  selected <- shiny::reactive({
    x <- visual()
    shiny::req(x)
    prior_draw_index(x, input[[paste0(id, "_draw_index")]])
  })
  output[[paste0(id, "_draw_controls")]] <- shiny::renderUI({
    x <- visual()
    shiny::req(x)
    shiny::tagList(
      shiny::sliderInput(
        paste0(id, "_draw_index"),
        "Selected realization",
        min = 1,
        max = length(x$draws$mean_low),
        value = 1,
        step = 1,
        sep = ""
      ),
      shiny::actionButton(paste0(id, "_draw_previous"), "Previous realization"),
      shiny::actionButton(paste0(id, "_draw_next"), "Next realization")
    )
  })
  observers <- lapply(c("previous", "next"), function(direction) {
    event_id <- paste0(id, "_draw_", direction)
    step <- if (direction == "next") 1L else -1L
    shiny::observeEvent(input[[event_id]], {
      x <- visual()
      shiny::req(x)
      shiny::updateSliderInput(
        session,
        paste0(id, "_draw_index"),
        value = prior_draw_index(x, selected() + step)
      )
    })
  })
  output[[paste0(id, "_draw_summary")]] <- shiny::renderText(prior_draw_summary(
    shiny::req(visual()),
    selected()
  ))
  output[[paste0(
    id,
    "_draw_probability"
  )]] <- shiny::renderText(prior_draw_probability(shiny::req(visual())))
  output[[paste0(id, "_draw_pair")]] <- shiny::renderPlot(
    prior_draw_plot(shiny::req(visual()), selected()),
    res = 110,
    alt = shiny::reactive(prior_draw_summary(shiny::req(visual()), selected()))
  )
  output[[paste0(id, "_draw_dots")]] <- shiny::renderPlot(
    prior_draw_plot(shiny::req(visual()), selected(), "dots"),
    res = 110,
    alt = shiny::reactive(prior_draw_probability(shiny::req(visual())))
  )
  invisible(list(
    outputs = paste0(
      id,
      c(
        "_draw_controls",
        "_draw_summary",
        "_draw_probability",
        "_draw_pair",
        "_draw_dots"
      )
    ),
    observers = observers
  ))
}
