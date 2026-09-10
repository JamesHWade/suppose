.libPaths(c(normalizePath('.suppose/runtime-library'), .libPaths()))
pkgload::load_all(quiet = TRUE)
for (kind in c('linear', 'curved', 'waiting')) {
  fit <- readRDS(file.path('artifacts', paste0('world-', kind, '-fit.rds')))
  w <- suppose_model_example(kind)
  d <- suppose:::world_scenarios(w)
  before <- digest::digest(fit)
  set.seed(978)
  rng <- .Random.seed
  actual <- inspect_model(
    fit,
    d,
    w$varying,
    unlist(w$units),
    w$outcome_units,
    w$title,
    w$scope,
    w$source,
    w$assumptions,
    w$training_range,
    w$threshold,
    lower_bound = w$lower_bound,
    draws = 400,
    seed = 47
  )
  stopifnot(
    identical(.Random.seed, rng),
    identical(before, digest::digest(fit))
  )
  direct <- withr::with_seed(47, {
    ids <- sort(sample.int(brms::ndraws(fit), 400))
    list(
      expected = brms::posterior_epred(fit, newdata = d, draw_ids = ids),
      future = brms::posterior_predict(fit, newdata = d, draw_ids = ids)
    )
  })
  stopifnot(
    isTRUE(all.equal(
      suppose:::world_matrix(actual, 'expected'),
      direct$expected
    )),
    isTRUE(all.equal(
      unname(suppose:::world_matrix(actual, 'future')),
      unname(direct$future)
    )),
    isTRUE(all.equal(actual$expected, w$expected)),
    isTRUE(all.equal(actual$future, w$future))
  )
  # Independently reconstruct each mean curve from coefficient draws.
  b <- brms::fixef(fit, summary = FALSE)[
    actual$provenance$draw_ids,
    ,
    drop = FALSE
  ]
  design <- stats::model.matrix(
    stats::delete.response(stats::terms(fit$formula$formula)),
    d
  )
  independent <- b %*% t(design)
  if (kind == 'waiting') {
    sigma <- brms::as_draws_matrix(fit)[actual$provenance$draw_ids, 'sigma']
    independent <- exp(independent + as.numeric(sigma)^2 / 2)
  }
  stopifnot(isTRUE(all.equal(
    unname(independent),
    unname(direct$expected),
    tolerance = 1e-10
  )))
  # Error handling is atomic and does not alter the caller's model or RNG.
  for (change in c(
    'group',
    'special',
    'algorithm',
    'data',
    'scenario',
    'units',
    'range',
    'draws'
  )) {
    bad <- fit
    args <- list(
      model = bad,
      scenarios = d,
      varying = w$varying,
      units = unlist(w$units),
      outcome_units = w$outcome_units,
      title = w$title,
      scope = w$scope,
      source = w$source,
      assumptions = w$assumptions,
      training_range = w$training_range,
      threshold = w$threshold
    )
    if (change == 'group') {
      args$model$formula$formula <- strength ~ temperature + (1 | batch)
    }
    if (change == 'special') {
      args$model$formula$formula <- strength ~ s(temperature)
    }
    if (change == 'algorithm') {
      args$model$algorithm <- 'meanfield'
    }
    if (change == 'data') {
      args$model$data[[w$response]][1] <- NA_real_
    }
    if (change == 'scenario') {
      args$scenarios[[w$varying]][2] <- args$scenarios[[w$varying]][1]
    }
    if (change == 'units') {
      args$units <- c(other = 'degC')
    }
    if (change == 'range') {
      args$training_range <- c(40, 20)
    }
    if (change == 'draws') {
      args$draws <- 1001
    }
    err <- tryCatch(do.call(inspect_model, args), error = identity)
    stopifnot(inherits(err, 'suppose_error'))
    cat('PASS', kind, change, 'rejected:', conditionMessage(err), '\n')
  }
  cat(
    'PASS',
    kind,
    'direct brms predictions, independent coefficient computation, preserved RNG and input model\n'
  )
}
r <- read_record('artifacts/model-world-browser-record.json')
stopifnot(
  length(r$model_worlds) == 2,
  length(r$model_implications) == 1,
  r$model_implications[[1]]$scenario == 36,
  r$model_implications[[1]]$realization == 2,
  is.null(r$observations),
  is.null(r$commitments)
)
stopifnot(isTRUE(all.equal(
  suppose:::decode_inquiry_history(
    suppose:::encode_inquiry_history(r, NULL, list())
  )$record,
  r
)))
cat(
  'PASS actual browser record validates and survives native-history encoding\n'
)
