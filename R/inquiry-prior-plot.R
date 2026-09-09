inquiry_prior_visual <- function(p) {
  if (is.null(p$candidate) || is.null(p$prediction)) {
    return(NULL)
  }
  list(
    means = p$candidate$means,
    mean_sd = p$candidate$mean_sd,
    conditions = p$candidate$conditions,
    condition_units = p$candidate$condition_units,
    units = p$claim$units,
    correlation = p$candidate$correlation,
    threshold = p$claim$threshold,
    summary = p$prediction$summary
  )
}

inquiry_prior_alt <- function(x) {
  if (is.null(x)) {
    return("No numerical prior has been specified.")
  }
  d <- x$summary$mean_difference
  b <- x$summary$batch_difference
  sprintf(
    paste0(
      "Two density plots. The upper plot shows uncertainty about the population mean at %s and %s %s, in %s; shaded areas contain the central 90 percent. ",
      "The lower plot compares the prior for the mean difference (second condition minus first) with the prediction for two future measurements. ",
      "The mean difference has a central 90 percent interval from %.2f to %.2f %s; future measurements have an interval from %.2f to %.2f %s. ",
      "The prior probability that the mean difference exceeds %s %s is %.1f percent. These are consequences of elicited beliefs, not observations."
    ),
    x$conditions[1],
    x$conditions[2],
    x$condition_units,
    x$units,
    d$lower,
    d$upper,
    x$units,
    b$lower,
    b$upper,
    x$units,
    x$threshold,
    x$units,
    100 * d$probability_above
  )
}

inquiry_prior_plot <- function(x) {
  print(prior_ggplot(x, "overview"))
  invisible(x)
}


inquiry_prior_output <- function(id) {
  bslib::navset_tab(
    bslib::nav_panel("Densities", shiny::plotOutput(id, height = "560px")),
    bslib::nav_panel(
      "Intervals",
      shiny::plotOutput(paste0(id, "_intervals"), height = "260px")
    ),
    bslib::nav_panel(
      "Explore",
      plotly::plotlyOutput(paste0(id, "_interactive"), height = "420px"),
      shiny::textOutput(paste0(id, "_summary"))
    )
  )
}

bind_inquiry_prior <- function(output, id, visual) {
  output[[id]] <- shiny::renderPlot(
    {
      x <- visual()
      shiny::req(x)
      inquiry_prior_plot(x)
    },
    res = 110,
    execOnResize = TRUE,
    alt = shiny::reactive(inquiry_prior_alt(visual()))
  )
  output[[paste0(id, "_intervals")]] <- shiny::renderPlot(
    {
      x <- visual()
      shiny::req(x)
      print(prior_ggplot(x, "intervals"))
    },
    res = 110,
    alt = shiny::reactive(sub(
      "Two density plots.*The mean difference",
      "Two central 90 percent interval plots. The mean difference",
      inquiry_prior_alt(visual())
    ))
  )
  output[[paste0(id, "_summary")]] <- shiny::renderText({
    x <- visual()
    shiny::req(x)
    d <- x$summary$mean_difference
    b <- x$summary$batch_difference
    sprintf(
      "Central 90%% interval: mean difference %.2f to %.2f %s; future measurements %.2f to %.2f %s. P(mean difference > %s %s) = %.1f%%. The brown dashed line marks the threshold.",
      d$lower,
      d$upper,
      x$units,
      b$lower,
      b$upper,
      x$units,
      x$threshold,
      x$units,
      100 * d$probability_above
    )
  })
  output[[paste0(id, "_interactive")]] <- plotly::renderPlotly({
    x <- visual()
    shiny::req(x)
    prior_plotly(x, "contrast")
  })
  invisible(NULL)
}
