sensitivity_fixture <- function(
  values = c(0, 0, 0, 100, 100, 100),
  conditions = rep(c("low", "high"), each = 3)
) {
  f <- update_fixture(values, conditions)
  x <- record_observations(f$record, f$obs, "Synthetic training data")
  fit <- update_prior(f$prior, f$obs, f$map, independent = TRUE)
  x <- record_update(x, fit, "Synthetic retained update")
  list(
    record = x,
    update = x$updates[[1]],
    prior = f$prior,
    observations = f$obs,
    map = f$map
  )
}
