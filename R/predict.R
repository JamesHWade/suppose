#' Inspect prior consequences with reproducible draws and exact summaries
#'
#' The contrast is the second mean minus the first. `probability_above` is a
#' conditional prior probability, not an assessment using observations.
#' Batch contrasts describe two independent future batch measurements, including
#' mean uncertainty and batch variation. RNG state is restored after simulation.
#' @param x A proposed prior.
#' @param n Number of simulation draws (2 to 1,000,000).
#' @param seed Explicit nonnegative integer seed.
#' @return A `suppose_prediction` containing draws, analytic summaries, and
#'   computation provenance. Intervals are central 90% intervals.
#' @export
predict_prior <- function(x, n = 4000L, seed = 1L) {
  check_seal(x, "suppose_prior")
  check_count(n, "n", 2)
  check_count(seed, "seed", 0, .Machine$integer.max)
  withr::local_seed(
    seed,
    .rng_kind = "Mersenne-Twister",
    .rng_normal_kind = "Inversion",
    .rng_sample_kind = "Rejection"
  )
  z1 <- stats::rnorm(n)
  z2 <- stats::rnorm(n)
  m1 <- x$means[1] + x$mean_sd[1] * z1
  m2 <- x$means[2] +
    x$mean_sd[2] * (x$correlation * z1 + sqrt(1 - x$correlation^2) * z2)
  y1 <- m1 + stats::rnorm(n, sd = x$batch_sd[1])
  y2 <- m2 + stats::rnorm(n, sd = x$batch_sd[2])
  delta_sd <- sqrt(max(
    0,
    sum(x$mean_sd^2) - 2 * x$correlation * prod(x$mean_sd)
  ))
  summary_row <- function(mean, sd, threshold = x$claim$threshold) {
    list(
      mean = mean,
      sd = sd,
      lower = mean + stats::qnorm(.05) * sd,
      upper = mean + stats::qnorm(.95) * sd,
      probability_above = if (sd == 0) {
        as.numeric(mean > threshold)
      } else {
        stats::pnorm(threshold, mean, sd, lower.tail = FALSE)
      }
    )
  }
  seal(
    list(
      prior_id = x$id,
      units = x$claim$units,
      threshold = x$claim$threshold,
      conditions = x$conditions,
      seed = seed,
      n = n,
      rng = "Mersenne-Twister/Inversion/Rejection",
      r_version = as.character(getRversion()),
      method = "normal-analytic-and-monte-carlo-v1",
      summary = list(
        mean_difference = summary_row(diff(x$means), delta_sd),
        batch_difference = summary_row(
          diff(x$means),
          sqrt(delta_sd^2 + sum(x$batch_sd^2))
        )
      ),
      draws = list(
        mean_low = m1,
        mean_high = m2,
        batch_low = y1,
        batch_high = y2,
        mean_difference = m2 - m1,
        batch_difference = y2 - y1
      )
    ),
    "suppose_prediction"
  )
}

#' @export
print.suppose_prediction <- function(x, ...) {
  s <- x$summary$mean_difference
  cli::cli_h2("Prior consequences")
  cli::cli_text(
    "Mean difference: {round(s$mean, 2)} {x$units}; central 90% interval [{round(s$lower, 2)}, {round(s$upper, 2)}]."
  )
  cli::cli_text(
    "P(mean difference > {x$threshold} {x$units} | model and prior) = {round(s$probability_above, 3)}"
  )
  cli::cli_text("Simulated outcomes, not observations. Seed: {x$seed}.")
  invisible(x)
}

#' @export
plot.suppose_prediction <- function(x, ...) {
  withr::local_par(list(mar = c(4, 4, 3, 1)))
  values <- c(x$draws$batch_difference, x$draws$mean_difference, x$threshold)
  breaks <- pretty(range(values), n = 40)
  h1 <- graphics::hist(x$draws$batch_difference, breaks = breaks, plot = FALSE)
  h2 <- graphics::hist(x$draws$mean_difference, breaks = breaks, plot = FALSE)
  graphics::plot(
    h1,
    freq = FALSE,
    col = "#dde6e2",
    border = "white",
    ylim = c(0, max(h1$density, h2$density)),
    main = "Prior consequences",
    xlab = paste("Difference in strength (", x$units, ")", sep = ""),
    ...
  )
  graphics::plot(
    h2,
    freq = FALSE,
    add = TRUE,
    col = grDevices::adjustcolor("#245747", alpha.f = .65),
    border = NA
  )
  graphics::abline(v = x$threshold, lty = 2, lwd = 2, col = "#ae512f")
  graphics::legend(
    "topright",
    c("Future batches", "Mean difference", "Threshold"),
    fill = c("#dde6e2", "#245747", NA),
    lty = c(NA, NA, 2),
    border = NA,
    bty = "n",
    cex = .7
  )
  invisible(x)
}
