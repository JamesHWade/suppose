# Independent reference checks for the deliberately bounded initial method.
pkgload::load_all(quiet = TRUE)
probs <- c(.05, .5, .95)
c <- claim(
  "Higher temperature improves mean strength",
  "Synthetic probe",
  target = "Second mean minus first",
  units = "MPa",
  scope = "F/P",
  threshold = 5
)
js <- list(
  judgment(
    140,
    qnorm(probs, 50, 3),
    probs,
    units = "MPa",
    author = "Probe",
    answer = "Known N(50, 3^2) prior"
  ),
  judgment(
    160,
    qnorm(probs, 58, 4),
    probs,
    units = "MPa",
    author = "Probe",
    answer = "Known N(58, 4^2) prior"
  )
)
p <- fit_prior(c, js, 0, c(3, 3))
y <- predict_prior(p, 100000, 42)
stopifnot(
  max(abs(p$means - c(50, 58))) < 1e-10,
  max(abs(p$mean_sd - c(3, 4))) < 1e-10,
  abs(y$summary$mean_difference$sd - 5) < 1e-10,
  abs(y$summary$mean_difference$probability_above - pnorm(.6)) < 1e-10
)
# The same two endpoint quantiles also admit a lognormal prior.
endpoints <- c(45, 55)
sdlog <- diff(log(endpoints)) / (2 * qnorm(.95))
meanlog <- mean(log(endpoints))
comparison <- data.frame(
  family = c("Normal", "Lognormal"),
  q05 = c(45, qlnorm(.05, meanlog, sdlog)),
  median = c(50, qlnorm(.5, meanlog, sdlog)),
  q95 = c(55, qlnorm(.95, meanlog, sdlog)),
  q999 = c(qnorm(.999, 50, 5 / qnorm(.95)), qlnorm(.999, meanlog, sdlog))
)
print(comparison)
cat("Maximum recovery error:", max(p$max_error, abs(p$means - c(50, 58))), "\n")
cat(
  "Reference contrast SD: 5; simulated SD:",
  sd(y$draws$mean_difference),
  "\n"
)
cat("Reference P(delta > 5):", pnorm(.6), "\n")
cat("Monte Carlo mean error:", abs(mean(y$draws$mean_difference) - 8), "\n")
cat("Negative future batch probability:", p$negative_batch_probability, "\n")
cat(
  "Both marginal families match the two endpoints; tails and dependence remain choices.\n"
)
