# Rebuild genuine brms fits and their portable teaching snapshots.
# Install brms and suppose before running; a working Stan toolchain is needed.
# Change output_dir for a fresh set of fits if you edit the model or data.
output_dir <- 'model-world-examples'
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
library(brms)
options(mc.cores = 2)
set.seed(817)
temperature <- rep(seq(20, 40, length.out = 16), 4)
d <- data.frame(
  temperature,
  strength = 65 +
    0.8 * (temperature - 30) -
    0.08 * (temperature - 30)^2 +
    rnorm(length(temperature), 0, 4)
)
for (kind in c('linear', 'curved')) {
  path <- file.path(output_dir, paste0('world-', kind, '-fit.rds'))
  if (!file.exists(path)) {
    form <- if (kind == 'linear') {
      strength ~ temperature
    } else {
      strength ~ temperature + I((temperature - 30)^2)
    }
    fit <- brm(
      form,
      data = d,
      family = gaussian(),
      prior = c(
        prior(normal(60, 20), class = Intercept),
        prior(normal(0, 2), class = b),
        prior(exponential(0.2), class = sigma)
      ),
      chains = 4,
      iter = 2000,
      warmup = 1000,
      seed = 817,
      control = list(adapt_delta = 0.99),
      refresh = 0
    )
    saveRDS(fit, path)
  }
}
library(suppose)
for (kind in c('linear', 'curved')) {
  fit <- readRDS(file.path(output_dir, paste0('world-', kind, '-fit.rds')))
  world <- inspect_model(
    fit,
    scenarios = data.frame(temperature = seq(0, 80, by = 2)),
    varying = 'temperature',
    units = c(temperature = 'degC'),
    outcome_units = 'MPa',
    title = if (kind == 'linear') {
      'Coating strength: a straight-line world'
    } else {
      'Coating strength: a curved world'
    },
    scope = 'Fictional independent coating preparations under a fixed protocol. Fit at 20–40 degC; other temperatures explore extrapolation.',
    source = 'Synthetic teaching data: 64 preparations generated with seed 817, a quadratic mean and Gaussian SD 4 MPa. Not measurements of real coatings.',
    assumptions = if (kind == 'linear') {
      'Analyst interpretation: a constant change in mean strength per degree, with common variability. No causal interpretation has been established.'
    } else {
      'Analyst interpretation: the mean can turn downward as temperature rises, with common variability. No causal interpretation has been established.'
    },
    training_range = c(20, 40),
    threshold = 60,
    lower_bound = 0,
    draws = 400,
    seed = 47
  )
  writeLines(
    jsonlite::toJSON(
      unclass(world),
      auto_unbox = FALSE,
      null = 'null',
      digits = NA
    ),
    file.path(output_dir, paste0(kind, '.json'))
  )
}
set.seed(918)
load <- rep(seq(20, 60, length.out = 20), 3)
waiting_data <- data.frame(
  load,
  waiting = rlnorm(length(load), -.4 + .025 * load, .3)
)
waiting_path <- file.path(output_dir, 'world-waiting-fit.rds')
if (!file.exists(waiting_path)) {
  waiting_fit <- brm(
    waiting ~ load,
    data = waiting_data,
    family = lognormal(),
    prior = c(
      prior(normal(1, .8), class = Intercept),
      prior(normal(0, .1), class = b),
      prior(exponential(3), class = sigma)
    ),
    chains = 4,
    iter = 2000,
    warmup = 1000,
    seed = 918,
    control = list(adapt_delta = .99),
    refresh = 0
  )
  saveRDS(waiting_fit, waiting_path)
}
waiting_fit <- readRDS(waiting_path)
waiting_world <- inspect_model(
  waiting_fit,
  scenarios = data.frame(load = seq(0, 100, by = 2)),
  varying = 'load',
  units = c(load = 'requests/minute'),
  outcome_units = 'minutes',
  title = 'Waiting times: a positive, skewed world',
  scope = 'Fictional independent requests under a fixed service configuration. Fit at 20–60 requests/minute; other loads explore extrapolation.',
  source = 'Synthetic teaching data: 60 waits generated with seed 918 from a lognormal model. Not measurements of a real service.',
  assumptions = 'Analyst interpretation: typical waiting time changes multiplicatively with load, with positive outcomes and a long right tail. This does not establish a queuing mechanism or an intervention effect.',
  training_range = c(20, 60),
  threshold = 5,
  lower_bound = 0,
  draws = 400,
  seed = 47
)
writeLines(
  jsonlite::toJSON(
    unclass(waiting_world),
    auto_unbox = FALSE,
    null = 'null',
    digits = NA
  ),
  file.path(output_dir, 'waiting.json')
)

# Reopen a fitted starting model with readRDS().
# Example: fit <- readRDS(file.path(output_dir, 'world-linear-fit.rds'))
# The variables world and waiting_world are ready for suppose_app(model = ...).
