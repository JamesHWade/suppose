# Development-only adapter evaluation; priorsense is not a runtime dependency.
.libPaths(c("/private/tmp/suppose-priorsense-library", .libPaths()))
pkgload::load_all(quiet = TRUE)
source("tests/testthat/helper-update.R")
f <- update_fixture()
u <- update_prior(f$prior, f$obs, f$map, independent = TRUE)
sigma <- outer(f$prior$mean_sd, f$prior$mean_sd) * matrix(c(1, 0.8, 0.8, 1), 2)
set.seed(15015)
n <- 40000
z <- matrix(rnorm(n * 2), n, 2)
draws <- sweep(
  z %*% chol(matrix(u$posterior$covariance, 2)),
  2,
  u$posterior$means,
  "+"
)
centered <- sweep(draws, 2, f$prior$means)
lprior <- -rowSums((centered %*% solve(sigma)) * centered) / 2
log_lik <- rep(0, n)
for (r in f$obs$rows) {
  group <- match(unname(f$map[[r$condition]]), f$prior$conditions)
  log_lik <- log_lik +
    dnorm(r$converted, draws[, group], f$prior$batch_sd[group], log = TRUE)
}
d <- posterior::as_draws_df(data.frame(
  difference = draws[, 2] - draws[, 1],
  lprior,
  log_lik
))
adapter <- priorsense::create_priorsense_data(d)
results <- list()
for (component in c("prior", "likelihood")) {
  for (alpha in c(0.8, 1, 1.25)) {
    powered <- priorsense::powerscale(
      adapter,
      component = component,
      alpha = alpha,
      variable = "difference"
    )
    ap <- if (component == "prior") alpha else 1
    al <- if (component == "likelihood") alpha else 1
    precision <- ap * solve(sigma) + al * diag(3 / f$prior$batch_sd^2)
    cov <- solve(precision)
    mu <- cov %*%
      (ap *
        solve(sigma, f$prior$means) +
        al * c(50, 60) * 3 / f$prior$batch_sd^2)
    w <- if (".log_weight" %in% names(powered)) {
      exp(powered$.log_weight - max(powered$.log_weight))
    } else {
      rep(1, n)
    }
    estimate <- sum(w * powered$difference) / sum(w)
    results[[length(results) + 1]] <- data.frame(
      component,
      alpha,
      estimate,
      reference = diff(as.numeric(mu)),
      error = estimate - diff(as.numeric(mu)),
      pareto_k = if (alpha == 1) {
        0
      } else {
        attr(powered, "powerscaling")$diagnostics$khat
      }
    )
    if (component == "prior" && alpha == 0.8) {
      capture.output(
        str(attributes(powered)),
        file = "artifacts/priorsense-adapter-attributes.txt"
      )
    }
  }
}
out <- do.call(rbind, results)
write.csv(out, "artifacts/priorsense-adapter-comparison.csv", row.names = FALSE)
print(packageVersion("priorsense"))
print(out)
stopifnot(all(abs(out$error) < 0.025))
