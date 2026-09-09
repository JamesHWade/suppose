#' Preview priors for a bounded Bayesian regression workflow
#'
#' Fits use independent normal observations and an unknown common variance.
#' The proper prior is `variance ~ inverse-gamma(shape, rate)` and
#' `beta | variance ~ normal(mean, variance * V)`. Its rate is
#' `(noise_shape - 1) * noise_sd^2`, so `noise_sd` is the square root of the
#' expected variance, not the mean noise SD. Marginal coefficient SDs are
#' `intercept_sd` and `effect_sd`. Coefficients share the uncertain variance:
#' conditional independence does not imply marginal independence.
#'
#' This is a new model specification, not an automatic conversion of earlier
#' elicited priors or retained extensions. Defaults are suggestions for review.
#' With two predictors, the first defines the baseline; the second is added.
#' Both use the same measurements, prior for shared parameters, and transforms.
#' @param x A record.
#' @param design_id Retained predictor dataset ID.
#' @param predictors One or two predictor names, in baseline/extension order.
#' @param location Prior mean of the outcome at the predictor reference values.
#' @param intercept_sd,effect_sd Positive marginal prior coefficient SDs, in
#'   outcome units and outcome units per meaningful predictor change.
#' @param noise_sd Positive prior root expected measurement variance.
#' @param noise_shape Inverse-gamma shape, greater than 2; default 3.
#' @param centers,scales Optional named numeric vectors for all selected
#'   predictors. Defaults use predictor midranges and half-ranges only, without
#'   looking at outcomes. These are recorded reference values, not learned effects.
#' @return A sealed specification with prior predictive intervals at all retained
#'   predictor rows for review before [fit_regression()].
#' @export
regression_prior <- function(
  x,
  design_id,
  predictors,
  location = 0,
  intercept_sd = 10,
  effect_sd = 5,
  noise_sd = 5,
  noise_shape = 3,
  centers = NULL,
  scales = NULL
) {
  validate_record(x)
  d <- regression_dataset(x, design_id)
  check_strings(predictors, "predictors")
  if (
    !length(predictors) ||
      length(predictors) > 2L ||
      anyDuplicated(predictors) ||
      !all(predictors %in% names(d$predictors))
  ) {
    abort_suppose(
      "Choose one baseline predictor and optionally one different added predictor."
    )
  }
  check_number(location, "location")
  for (name in c("intercept_sd", "effect_sd", "noise_sd")) {
    check_number(get(name), name, 0)
    if (get(name) == 0) abort_suppose("Prior scales must be positive.")
  }
  check_number(noise_shape, "noise_shape", 2)
  if (noise_shape == 2) {
    abort_suppose("Use a variance prior shape greater than 2.")
  }
  for (name in c("centers", "scales")) {
    v <- get(name)
    if (
      !is.null(v) &&
        (!is.numeric(v) ||
          !all(is.finite(v)) ||
          is.null(names(v)) ||
          anyDuplicated(names(v)) ||
          !setequal(names(v), predictors))
    ) {
      abort_suppose(
        "Name one finite {.arg {name}} value for every selected predictor."
      )
    }
  }
  if (!is.null(scales) && any(scales <= 0)) {
    abort_suppose("Predictor scales must be positive.")
  }
  transforms <- lapply(predictors, function(name) {
    limits <- range(d$predictors[[name]])
    list(
      name = name,
      units = d$design$units[[name]],
      center = if (is.null(centers)) mean(limits) else unname(centers[[name]]),
      scale = if (is.null(scales)) diff(limits) / 2 else unname(scales[[name]])
    )
  })
  priors <- lapply(seq_along(predictors), function(k) {
    list(
      mean = c(location, rep(0, k)),
      v_diagonal = (c(intercept_sd, rep(effect_sd, k)) / noise_sd)^2,
      shape = noise_shape,
      rate = (noise_shape - 1) * noise_sd^2,
      terms = c("intercept", predictors[seq_len(k)]),
      label = if (k == 1L) "baseline" else "extended"
    )
  })
  for (prior in priors) {
    if (
      !all(is.finite(c(prior$v_diagonal, prior$rate))) ||
        any(prior$v_diagonal <= 0) ||
        prior$rate <= 0
    ) {
      abort_suppose(
        "Prior scales exceed the supported numerical range.",
        "computation"
      )
    }
  }
  spec <- list(
    record_id = x$record_id,
    basis_id = proposal_basis_id(x),
    design_id = design_id,
    evidence_id = d$evidence$id,
    claim_id = d$evidence$claim_id,
    revision = d$evidence$revision,
    units = d$evidence$data$target_units,
    predictor_units = d$design$units,
    observation_ids = d$ids,
    predictors = predictors,
    transforms = transforms,
    settings = list(
      location = location,
      intercept_sd = intercept_sd,
      effect_sd = effect_sd,
      noise_sd = noise_sd,
      noise_shape = noise_shape
    ),
    priors = priors,
    assumptions = c(
      "Independent normal observations with one unknown common measurement variance; no clusters, time dependence, interactions or measurement error in predictors.",
      "Normal coefficient priors conditional on the same inverse-gamma variance; coefficients are marginally dependent through that variance.",
      "A new prior specification: earlier fixed-noise models and additive-extension judgments are not automatically carried into this regression.",
      "Predictor transformations are fixed from their values or supplied settings, never from outcomes. Shared parameter priors remain identical when adding a predictor.",
      "These defaults are starting suggestions, not attributed beliefs. Prior and posterior predictions are model consequences, not empirical validation."
    ),
    created_at = now_utc()
  )
  spec$prior_predictions <- lapply(priors, function(prior) {
    design <- regression_model_matrix(d, transforms, prior$terms[-1])
    regression_predict_rows(
      prior$mean,
      diag(prior$v_diagonal),
      prior$shape,
      prior$rate,
      design,
      d$ids
    )
  })
  spec$prior_changes <- regression_prior_changes(spec, d$predictors)
  seal(spec, "suppose_regression_spec")
}

regression_prior_changes <- function(spec, predictors) {
  prior <- utils::tail(spec$priors, 1)[[1]]
  lapply(seq_along(spec$transforms), function(i) {
    t <- spec$transforms[[i]]
    limits <- range(predictors[[t$name]])
    contrast <- diff(limits) / t$scale
    location <- contrast * prior$mean[i + 1L]
    scale <- abs(contrast) *
      sqrt(prior$rate / prior$shape * prior$v_diagonal[i + 1L])
    interval <- location +
      stats::qt(c(0.05, 0.95), df = 2 * prior$shape) * scale
    list(
      predictor = t$name,
      from = limits[1],
      to = limits[2],
      predictor_units = t$units,
      mean = location,
      lower = interval[1],
      upper = interval[2],
      units = spec$units,
      probability = 0.9,
      interpretation = "Prior change in the population mean, holding other predictors fixed. Excludes new-measurement noise; not a causal effect or a guarantee of joint predictor support."
    )
  })
}

regression_model_matrix <- function(d, transforms, predictors) {
  columns <- lapply(predictors, function(name) {
    transform <- Filter(function(t) identical(t$name, name), transforms)[[1]]
    (d$predictors[[name]] - transform$center) / transform$scale
  })
  result <- cbind(1, do.call(cbind, columns))
  if (!all(is.finite(result))) {
    abort_suppose(
      "Predictor transformation exceeds the numerical range.",
      "computation"
    )
  }
  result
}

regression_posterior <- function(design, y, prior) {
  precision <- diag(1 / prior$v_diagonal)
  v <- chol2inv(chol(precision + crossprod(design)))
  v[v == 0] <- 0
  m <- drop(v %*% (precision %*% prior$mean + crossprod(design, y)))
  residual <- y - drop(design %*% m)
  delta <- m - prior$mean
  rate <- prior$rate + (sum(residual^2) + sum(delta^2 / prior$v_diagonal)) / 2
  shape <- prior$shape + length(y) / 2
  if (!all(is.finite(c(v, m, rate, shape))) || rate <= 0) {
    abort_suppose(
      "Regression exceeds the numerical range; no fit was retained.",
      "computation"
    )
  }
  list(mean = m, v = v, shape = shape, rate = rate)
}

regression_predict_rows <- function(mean, v, shape, rate, design, ids) {
  mu <- drop(design %*% mean)
  variance_factor <- rowSums((design %*% v) * design)
  if (any(variance_factor < -1e-8)) {
    abort_suppose("Invalid predictive variance.", "computation")
  }
  mean_scale <- sqrt(pmax(0, variance_factor) * rate / shape)
  outcome_scale <- sqrt((1 + pmax(0, variance_factor)) * rate / shape)
  quantile <- stats::qt(0.95, 2 * shape)
  if (!all(is.finite(c(mu, mean_scale, outcome_scale, quantile)))) {
    abort_suppose(
      "Predictive calculation exceeds the numerical range.",
      "computation"
    )
  }
  lapply(seq_along(mu), function(i) {
    row <- list(
      observation_id = ids[i],
      mean = mu[i],
      df = 2 * shape,
      mean_scale = mean_scale[i],
      outcome_scale = outcome_scale[i],
      mean_lower = mu[i] - quantile * mean_scale[i],
      mean_upper = mu[i] + quantile * mean_scale[i],
      outcome_lower = mu[i] - quantile * outcome_scale[i],
      outcome_upper = mu[i] + quantile * outcome_scale[i]
    )
    if (!all(is.finite(unlist(row[-1], use.names = FALSE)))) {
      abort_suppose(
        "Predictive intervals exceed the numerical range.",
        "computation"
      )
    }
    row
  })
}

#' Fit and check a reviewed regression specification
#'
#' Posterior parameters and leave-one-out predictions use exact conjugate
#' calculations. Posterior predictive checks draw the shared variance and joint
#' coefficient vector, then replicate all outcomes together. No MCMC is used.
#' Leave-one-out fits hold priors and transformations fixed in every fold.
#' @param x A record.
#' @param spec A result from [regression_prior()].
#' @param independent Explicit assertion of independent measurement units.
#'   Repeated batch/specimen pairs are rejected even with this assertion.
#' @param reviewed Explicit confirmation of reviewing the new prior assumptions.
#' @param draws Number of joint posterior predictive replicates (200 to 5000).
#' @param seed Reproducible predictive-check seed; does not alter the caller RNG.
#' @return A sealed result with exact fits, predictive checks and optional paired
#'   leave-one-out comparison. No result is retained automatically.
#' @export
fit_regression <- function(
  x,
  spec,
  independent = FALSE,
  reviewed = FALSE,
  draws = 1000,
  seed = 1
) {
  validate_record(x)
  check_seal(spec, "suppose_regression_spec")
  if (!identical(spec$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Preview regression priors again.",
      "stale"
    )
  }
  if (!isTRUE(independent) || !isTRUE(reviewed)) {
    abort_suppose(
      "Review the prior assumptions and confirm independent measurement units before fitting.",
      "review"
    )
  }
  check_count(draws, "draws", 200, 5000)
  check_count(seed, "seed", 0, .Machine$integer.max)
  d <- regression_dataset(x, spec$design_id)
  specimen <- vapply(
    d$evidence$data$rows,
    function(r) object_id(list(r$batch, r$specimen)),
    character(1)
  )
  if (anyDuplicated(specimen)) {
    abort_suppose(
      "Repeated specimens require a dependence model.",
      "independence"
    )
  }
  fits <- lapply(seq_along(spec$priors), function(k) {
    prior <- spec$priors[[k]]
    design <- regression_model_matrix(d, spec$transforms, prior$terms[-1])
    if (qr(design)$rank < ncol(design)) {
      abort_suppose(
        "Selected predictors are collinear; review the model before fitting.",
        "design"
      )
    }
    post <- regression_posterior(design, d$y, prior)
    predictions <- regression_predict_rows(
      post$mean,
      post$v,
      post$shape,
      post$rate,
      design,
      d$ids
    )
    loo <- lapply(seq_along(d$y), function(i) {
      fold <- regression_posterior(design[-i, , drop = FALSE], d$y[-i], prior)
      pred <- regression_predict_rows(
        fold$mean,
        fold$v,
        fold$shape,
        fold$rate,
        design[i, , drop = FALSE],
        d$ids[i]
      )[[1]]
      pred$log_score <- stats::dt(
        (d$y[i] - pred$mean) / pred$outcome_scale,
        df = pred$df,
        log = TRUE
      ) -
        log(pred$outcome_scale)
      pred
    })
    scores <- vapply(loo, `[[`, numeric(1), "log_score")
    if (!all(is.finite(scores))) {
      abort_suppose(
        "Leave-one-out prediction failed; no comparison was retained.",
        "computation"
      )
    }
    q <- stats::qt(0.95, 2 * post$shape)
    coefficients <- lapply(seq_along(prior$terms), function(i) {
      scale <- sqrt(post$v[i, i] * post$rate / post$shape)
      list(
        term = prior$terms[i],
        mean = post$mean[i],
        lower = post$mean[i] - q * scale,
        upper = post$mean[i] + q * scale
      )
    })
    list(
      label = prior$label,
      terms = prior$terms,
      posterior = list(
        mean = post$mean,
        v = lapply(seq_len(nrow(post$v)), function(i) unname(post$v[i, ])),
        shape = post$shape,
        rate = post$rate
      ),
      coefficients = coefficients,
      noise = list(
        lower = sqrt(1 / stats::qgamma(0.95, post$shape, rate = post$rate)),
        median = sqrt(1 / stats::qgamma(0.5, post$shape, rate = post$rate)),
        upper = sqrt(1 / stats::qgamma(0.05, post$shape, rate = post$rate))
      ),
      predictions = predictions,
      loo = loo,
      elpd = sum(scores),
      checks = regression_ppc(d, design, post, draws, seed),
      computation = "Exact normal/inverse-gamma conditioning and exact leave-one-out refits. No sampler convergence diagnostics apply."
    )
  })
  comparison <- NULL
  if (length(fits) == 2L) {
    difference <- vapply(fits[[2]]$loo, `[[`, numeric(1), "log_score") -
      vapply(fits[[1]]$loo, `[[`, numeric(1), "log_score")
    comparison <- list(
      extended_minus_baseline = sum(difference),
      paired_se = sqrt(length(difference) * stats::var(difference)),
      pointwise = as.list(stats::setNames(difference, d$ids)),
      interpretation = "Positive values favor the extended model for leave-one-out prediction of exchangeable observations. The paired standard error is approximate, especially with small samples or influential points. It is not a posterior model probability, an independent prospective test or protection against repeated model-search selection bias."
    )
  }
  seal(
    list(
      spec = spec,
      fits = fits,
      comparison = comparison,
      observed = as.list(stats::setNames(d$y, d$ids)),
      predictor_values = d$predictors,
      independent = TRUE,
      reviewed = TRUE,
      draws = draws,
      seed = seed,
      method = "normal-inverse-gamma-regression-v1",
      created_at = now_utc()
    ),
    "suppose_regression"
  )
}

regression_ppc <- function(d, design, post, draws, seed) {
  withr::with_seed(seed, {
    n <- length(d$y)
    p <- ncol(design)
    noise <- sqrt(1 / stats::rgamma(draws, post$shape, rate = post$rate))
    beta <- sweep(
      matrix(stats::rnorm(draws * p), draws, p) %*% chol(post$v),
      1,
      noise,
      `*`
    )
    beta <- sweep(beta, 2, post$mean, `+`)
    mu <- beta %*% t(design)
    replicated <- mu + matrix(stats::rnorm(draws * n), draws, n) * noise
    observed_residual <- matrix(d$y, draws, n, byrow = TRUE) - mu
    replicated_residual <- replicated - mu
    statistics <- list(
      mean = list(
        observed = rep(mean(d$y), draws),
        replicated = rowMeans(replicated)
      ),
      spread = list(
        observed = rep(stats::sd(d$y), draws),
        replicated = apply(replicated, 1, stats::sd)
      ),
      largest_residual = list(
        observed = apply(abs(observed_residual / noise), 1, max),
        replicated = apply(abs(replicated_residual / noise), 1, max)
      )
    )
    for (name in names(d$predictors)) {
      values <- d$predictors[[name]]
      statistics[[paste0("residual_pattern_", name)]] <- list(
        observed = apply(observed_residual, 1, function(r) {
          abs(stats::cor(r, values))
        }),
        replicated = apply(replicated_residual, 1, function(r) {
          abs(stats::cor(r, values))
        })
      )
    }
    lapply(names(statistics), function(name) {
      s <- statistics[[name]]
      if (!all(is.finite(c(s$observed, s$replicated)))) {
        abort_suppose(
          "A predictive check could not be computed.",
          "computation"
        )
      }
      probability <- mean(s$replicated >= s$observed)
      mc_interval <- unname(
        stats::binom.test(
          sum(s$replicated >= s$observed),
          draws
        )$conf.int
      )
      uncertain <- any(vapply(
        c(0.025, 0.975),
        function(bound) {
          mc_interval[1] <= bound && mc_interval[2] >= bound
        },
        logical(1)
      ))
      list(
        statistic = name,
        observed = stats::median(s$observed),
        replicated = s$replicated,
        tail_area = probability,
        mcse = sqrt(probability * (1 - probability) / draws),
        mc_interval = mc_interval,
        resolution = 1 / draws,
        status = if (uncertain) {
          "simulation_uncertain"
        } else if (probability < 0.025 || probability > 0.975) {
          "review_mismatch"
        } else {
          "not_flagged"
        },
        interpretation = "Posterior predictive discrepancy check, reusing fitted data. Tail areas are not model probabilities; no flag does not establish adequate fit. Monte Carlo error applies to these simulated checks, not the exact fit."
      )
    })
  })
}

#' Retain a reviewed regression result and model choice
#' @param x A record.
#' @param result Result from [fit_regression()].
#' @param choice `baseline`, `extended` (if fitted), or `neither`.
#' @param author Person reviewing the results.
#' @param reason Scientific reason for the choice and remaining limitations.
#' @param reviewed Explicit confirmation that diagnostics and comparison were reviewed.
#' @param form_draft Optional original chat form draft.
#' @return A record with an append-only reviewed regression result. Earlier
#'   models, fits and prospective tests are not replaced or relabeled.
#' @export
record_regression <- function(
  x,
  result,
  choice,
  author,
  reason,
  reviewed = FALSE,
  form_draft = NULL
) {
  validate_record(x)
  check_seal(result, "suppose_regression")
  if (!isTRUE(reviewed)) {
    abort_suppose(
      "Review predictive checks and model comparisons before retaining a choice.",
      "review"
    )
  }
  if (!identical(result$spec$basis_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed. Refit against the current record before retaining.",
      "stale"
    )
  }
  check_text(author, "author")
  check_text(reason, "reason")
  check_text(choice, "choice")
  if (
    !choice %in% c("neither", vapply(result$fits, `[[`, character(1), "label"))
  ) {
    abort_suppose("Choose one of the fitted models or neither.")
  }
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      !identical(form_draft$form, "regression") ||
        !identical(form_draft$base_id, result$spec$basis_id)
    ) {
      abort_suppose(
        "This form draft belongs to a different regression basis.",
        "reference"
      )
    }
  }
  entry <- seal(
    list(
      result = result,
      choice = choice,
      author = author,
      reason = reason,
      form_draft = form_draft,
      created_at = now_utc()
    ),
    "suppose_regression_entry"
  )
  x$regressions <- c(x$regressions, list(entry))
  x$schema_version <- max(x$schema_version, 10L)
  validate_record(x)
  x
}

regression_inventory <- function(x) {
  lapply(x$regressions, function(e) {
    list(
      id = e$id,
      choice = e$choice,
      reason = e$reason,
      author = e$author,
      independent_units_confirmed = e$result$independent,
      revision = e$result$spec$revision,
      assumptions = e$result$spec$assumptions,
      settings = e$result$spec$settings,
      transforms = e$result$spec$transforms,
      comparison = e$result$comparison,
      fits = lapply(e$result$fits, function(f) {
        list(
          label = f$label,
          terms = f$terms,
          coefficients = f$coefficients,
          noise = f$noise,
          elpd = f$elpd,
          computation = f$computation,
          checks = lapply(f$checks, function(c) {
            c[setdiff(names(c), "replicated")]
          })
        )
      })
    )
  })
}

#' Predict new cases with a fitted regression
#'
#' Uses the fitted prior transformations without recalibration. Intervals are
#' marginal central 90% intervals for uncertain means and single future outcomes;
#' they are not simultaneous intervals or a frozen prospective test.
#' @param x A result from [fit_regression()].
#' @param data Data frame containing exactly the selected model's numeric
#'   predictor columns, in their original units; one to 500 cases.
#' @param model Fitted model label; defaults to the last fitted model.
#' @return A list with fit/model references, units, predictive rows and flags for
#'   values outside the observed predictor ranges. No outcomes are observed or
#'   assessments recorded by this function.
#' @export
predict_regression <- function(
  x,
  data,
  model = utils::tail(x$fits, 1)[[1]]$label
) {
  check_seal(x, "suppose_regression")
  check_text(model, "model")
  fits <- Filter(function(f) identical(f$label, model), x$fits)
  if (length(fits) != 1L) {
    abort_suppose("Select a fitted model label.")
  }
  f <- fits[[1]]
  fields <- f$terms[-1]
  if (
    !is.data.frame(data) ||
      nrow(data) < 1L ||
      nrow(data) > 500L ||
      anyDuplicated(names(data)) ||
      !setequal(names(data), fields)
  ) {
    abort_suppose(
      "Supply one to 500 cases with exactly the selected model's predictor columns."
    )
  }
  for (field in fields) {
    if (!is.numeric(data[[field]]) || !all(is.finite(data[[field]]))) {
      abort_suppose(
        "New predictor values must be finite numbers in the original units."
      )
    }
  }
  design <- regression_model_matrix(
    list(predictors = as.list(data)),
    x$spec$transforms,
    fields
  )
  p <- f$posterior
  rows <- regression_predict_rows(
    p$mean,
    do.call(rbind, p$v),
    p$shape,
    p$rate,
    design,
    paste0("case", seq_len(nrow(data)))
  )
  for (i in seq_along(rows)) {
    rows[[i]]$outside_observed_range <- any(vapply(
      fields,
      function(field) {
        limits <- range(x$predictor_values[[field]])
        data[[field]][i] < limits[1] || data[[field]][i] > limits[2]
      },
      logical(1)
    ))
    rows[[i]]$predictors <- as.list(data[i, fields, drop = FALSE])
  }
  list(
    fit_id = x$id,
    model = model,
    units = x$spec$units,
    rows = rows,
    interpretation = "Marginal model predictions under the recorded assumptions. Outside-range flags do not certify interpolation support, causal meaning or prospective validation."
  )
}
