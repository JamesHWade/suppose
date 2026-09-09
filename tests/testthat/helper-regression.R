regression_fixture <- function(
  n = 40L,
  role = "update",
  exposure = "explored",
  missing = FALSE,
  repeated = FALSE
) {
  x <- suppose_example()
  temperature <- rep(c(140, 150, 160, 150), length.out = n)
  duration <- rep(c(50, 50, 70, 70, 60), length.out = n)
  y <- 54 +
    0.4 * (temperature - 150) +
    1.8 * (duration - 60) +
    rep(c(-1, 1, -2, 2, 0), length.out = n)
  rows <- data.frame(
    observation_id = paste0("r", seq_len(n)),
    condition = as.character(temperature),
    outcome = y,
    batch = paste0("b", seq_len(n)),
    specimen = paste0("s", seq_len(n)),
    observed_at = "unknown"
  )
  if (missing) {
    rows$outcome[1] <- NA_real_
  }
  if (repeated) {
    rows$batch[2] <- rows$batch[1]
    rows$specimen[2] <- rows$specimen[1]
  }
  o <- import_observations(
    rows,
    "synthetic:regression",
    "Invented independent measurements",
    "Synthetic analyst",
    "MPa",
    role,
    exposure
  )
  x <- record_observations(x, o, "Synthetic regression workflow")
  data <- data.frame(
    observation_id = rows$observation_id,
    temperature,
    duration
  )
  predictors <- regression_predictors(
    x,
    x$observations[[1]]$id,
    data,
    c(temperature = "degC", duration = "minutes"),
    "synthetic:covariates",
    "Synthetic analyst"
  )
  x <- record_predictors(x, predictors)
  list(record = x, design = predictors, rows = rows, data = data)
}

regression_test_prior <- function(
  f,
  predictors = c("temperature", "duration")
) {
  regression_prior(
    f$record,
    f$design$id,
    predictors,
    location = 54,
    intercept_sd = 10,
    effect_sd = 20,
    noise_sd = 3
  )
}
