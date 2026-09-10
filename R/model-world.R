#' Inspect the world implied by a fitted brms model
#'
#' Compute a portable, data-only snapshot of a univariate model at explicit
#' scenarios. Each retained draw contains a coherent expected-response curve and
#' one simulated outcome per scenario, using the same posterior draw identifiers.
#' Scientific meaning, units and applicability are supplied by the author.
#' This does not establish causal effects or empirical model adequacy.
#'
#' The first adapter supports univariate brms models without group-level terms,
#' autocorrelation, censoring, truncation, or response-side addition terms.
#' Gaussian (identity or log link) and lognormal (identity link) likelihoods
#' are supported; ordinary arithmetic formula transformations are allowed.
#' These require an explicit joint prediction contract in a subsequent adapter.
#' Only numeric predictors and complete scenarios are accepted. Predictions are
#' conditional on the supplied inputs; they do not model their distribution.
#' The fit remains in the caller's R session and is not serialized into a record.
#' @param model A fitted `brmsfit`.
#' @param scenarios A data frame of numeric predictor settings, 2 to 101 rows.
#' @param varying Name of the predictor shown on the horizontal axis. Other
#'   predictors must be constant across these scenarios.
#' @param units Named character vector giving units for every predictor.
#' @param outcome_units Units of the response.
#' @param title Short name for the model.
#' @param scope Population, operating regime and interpretation of predictions.
#' @param source Provenance of the fitting data; explicitly label synthetic data.
#' @param assumptions Author-supplied scientific assumptions, as text.
#' @param training_range Observed range of `varying` in the fitting data.
#'   Defaults to the actual range. If supplied, it must match that range.
#'   Being inside a marginal fitting range does not establish applicability.
#' @param threshold Meaningful response threshold in outcome units.
#' @param lower_bound Optional scientifically impossible lower boundary.
#' @param draws Number of posterior draws to retain, from 50 to 1000.
#' @param seed Integer prediction seed.
#' @return A sealed `suppose_model_world` containing scenarios, predictions,
#'   structure and run provenance. Open with `suppose_app(model = world)`.
#' @export
inspect_model <- function(
  model,
  scenarios,
  varying,
  units,
  outcome_units,
  title,
  scope,
  source,
  assumptions,
  training_range = NULL,
  threshold,
  lower_bound = NULL,
  draws = 400L,
  seed = 47L
) {
  rlang::check_installed('brms')
  if (!inherits(model, 'brmsfit')) {
    abort_suppose('model must be a fitted brmsfit.')
  }
  for (arg in c(
    'varying',
    'outcome_units',
    'title',
    'scope',
    'source',
    'assumptions'
  )) {
    check_text(get(arg), arg)
  }
  check_count(draws, 'draws', 50, 1000)
  check_count(seed, 'seed', 0, .Machine$integer.max)
  check_number(threshold, 'threshold')
  if (!is.null(lower_bound)) {
    check_number(lower_bound, 'lower_bound')
  }
  if (
    !is.data.frame(scenarios) ||
      nrow(scenarios) < 2 ||
      nrow(scenarios) > 101 ||
      !ncol(scenarios) ||
      anyDuplicated(names(scenarios)) ||
      !all(vapply(
        scenarios,
        function(v) is.numeric(v) && all(is.finite(v)),
        logical(1)
      ))
  ) {
    abort_suppose(
      'scenarios must contain 2 to 101 complete numeric predictor rows.'
    )
  }
  check_strings(units, 'units')
  if (
    !setequal(names(units), names(scenarios)) || anyDuplicated(names(units))
  ) {
    abort_suppose('Supply named units for every scenario predictor.')
  }
  if (
    !varying %in% names(scenarios) ||
      is.unsorted(scenarios[[varying]], strictly = TRUE)
  ) {
    abort_suppose('The varying predictor must be strictly increasing.')
  }
  if (
    any(vapply(
      scenarios[setdiff(names(scenarios), varying)],
      function(v) length(unique(v)) != 1L,
      logical(1)
    ))
  ) {
    abort_suppose('Only one predictor may vary in this walkthrough.')
  }
  if (!identical(model$algorithm, 'sampling')) {
    abort_suppose(
      'This adapter requires an MCMC sampling fit, not an approximation or optimization fit.'
    )
  }
  if (identical(attr(model$prior, 'sample_prior'), 'only')) {
    abort_suppose(
      'A prior-only fit needs a separate prior-predictive contract; this adapter describes fitted posterior predictions.'
    )
  }
  if (length(model$stanvars)) {
    abort_suppose('Custom Stan code requires a separate prediction contract.')
  }
  form <- stats::formula(model)
  if (
    !inherits(form, 'brmsformula') ||
      length(form$pforms) ||
      grepl('\\|', paste(deparse(form$formula), collapse = '')) ||
      !is.null(form$autocor) ||
      length(form$acformula) ||
      !is.null(model$autocor)
  ) {
    abort_suppose(
      'This adapter currently requires a univariate model without group terms, response additions, autocorrelation or distributional formulas.'
    )
  }
  f <- form$formula
  if (length(all.vars(f[[2]])) != 1 || !is.symbol(f[[2]])) {
    abort_suppose(
      'Response-side additions require a separate prediction contract.'
    )
  }
  allowed <- c('+', '-', '*', '/', ':', '^', 'I', '(', 'log', 'sqrt', 'exp')
  walk <- function(z) {
    if (!is.call(z)) {
      return(TRUE)
    }
    head <- z[[1]]
    if (!is.symbol(head) || !as.character(head) %in% allowed) {
      return(FALSE)
    }
    all(vapply(as.list(z)[-1], walk, logical(1)))
  }
  if (!walk(f[[3]]) || isTRUE(attr(f, 'nl')) || length(form$pfix)) {
    abort_suppose(
      'This adapter supports ordinary numeric formula terms and explicit arithmetic transformations; smooths, special terms, fixed distributional parameters and nonlinear parameter formulas need a separate contract.'
    )
  }
  response <- as.character(f[[2]])
  predictors <- all.vars(f[[3]])
  if (!setequal(predictors, names(scenarios))) {
    abort_suppose(
      'scenarios must contain exactly the predictors in the model formula.'
    )
  }
  if (
    !is.data.frame(model$data) ||
      !all(c(response, predictors) %in% names(model$data)) ||
      !all(vapply(
        model$data[c(response, predictors)],
        function(v) is.numeric(v) && all(is.finite(v)),
        logical(1)
      ))
  ) {
    abort_suppose(
      'The model must retain complete finite numeric fitting data for the response and predictors.'
    )
  }
  observed_range <- unname(range(model$data[[varying]]))
  training_range <- training_range %||% observed_range
  if (
    !is.numeric(training_range) ||
      length(training_range) != 2 ||
      !all(is.finite(training_range)) ||
      training_range[1] >= training_range[2]
  ) {
    abort_suppose('training_range must contain two increasing finite values.')
  }
  if (
    !isTRUE(all.equal(
      unname(training_range),
      observed_range,
      tolerance = 1e-12
    ))
  ) {
    abort_suppose(
      'training_range must match the observed range of the varying predictor in the retained fitting data.'
    )
  }
  fam <- stats::family(model)
  # Restrict support to likelihoods with a simple, explicit simulation contract.
  valid_links <- list(gaussian = c('identity', 'log'), lognormal = 'identity')
  if (
    !fam$family %in% names(valid_links) ||
      !fam$link %in% valid_links[[fam$family]]
  ) {
    abort_suppose(
      'Supported families are gaussian (identity or log link) and lognormal (identity link).'
    )
  }
  total <- brms::ndraws(model)
  if (total < draws) {
    abort_suppose('The model has fewer retained draws than requested.')
  }
  result <- tryCatch(
    withr::with_seed(seed, {
      ids <- sort(sample.int(total, draws))
      list(
        ids = ids,
        expected = brms::posterior_epred(
          model,
          newdata = scenarios,
          draw_ids = ids
        ),
        future = brms::posterior_predict(
          model,
          newdata = scenarios,
          draw_ids = ids
        )
      )
    }),
    error = function(e) {
      abort_suppose(
        'Prediction failed; no snapshot was retained.',
        'prediction',
        parent = e
      )
    }
  )
  for (name in c('expected', 'future')) {
    a <- result[[name]]
    if (
      !is.matrix(a) ||
        !identical(dim(a), c(as.integer(draws), nrow(scenarios))) ||
        !all(is.finite(a))
    ) {
      abort_suppose(
        'The adapter requires finite draws by scenarios prediction matrices.'
      )
    }
  }
  formula_text <- paste(deparse(f, width.cutoff = 500L), collapse = ' ')
  structure_text <- c(
    paste('Response formula:', formula_text),
    paste('Likelihood:', fam$family, '; link:', fam$link),
    'Predictions condition on the supplied inputs; predictor frequencies are not modeled.',
    'Each simulated experiment uses one shared parameter draw and conditionally independent outcomes at the supplied rows.'
  )
  if (fam$family == 'gaussian') {
    structure_text <- c(
      structure_text,
      'The Gaussian likelihood permits negative outcomes and uses a common residual SD across these scenarios.'
    )
  }
  if (fam$family == 'lognormal') {
    structure_text <- c(
      structure_text,
      'The lognormal likelihood requires positive outcomes and uses a common residual SD on the log scale. Expected outcomes include the lognormal mean adjustment.'
    )
  }
  summary <- summary(model)
  rhats <- c(summary$fixed[, 'Rhat'], summary$spec_pars[, 'Rhat'])
  rhats <- rhats[is.finite(rhats)]
  ess <- c(summary$fixed[, 'Bulk_ESS'], summary$spec_pars[, 'Bulk_ESS'])
  ess <- ess[is.finite(ess)]
  np <- brms::nuts_params(model)
  div <- sum(np$Value[np$Parameter == 'divergent__'])
  out <- seal(
    list(
      title = title,
      scope = scope,
      source = source,
      assumptions = assumptions,
      response = response,
      outcome_units = outcome_units,
      varying = varying,
      units = as.list(units[names(scenarios)]),
      training_range = unname(training_range),
      threshold = threshold,
      lower_bound = lower_bound,
      fitting_points = lapply(
        seq_len(
          if (length(predictors) == 1L) min(nrow(model$data), 1000L) else 0L
        ),
        function(i) {
          list(
            x = as.numeric(model$data[[varying]][i]),
            y = as.numeric(model$data[[response]][i])
          )
        }
      ),
      fitting_rows = nrow(model$data),
      scenarios = lapply(seq_len(nrow(scenarios)), function(i) {
        as.list(scenarios[i, , drop = FALSE])
      }),
      expected = lapply(seq_len(draws), function(i) {
        unname(result$expected[i, ])
      }),
      future = lapply(seq_len(draws), function(i) unname(result$future[i, ])),
      structure = structure_text,
      formula = formula_text,
      family = fam$family,
      link = fam$link,
      priors = paste(
        utils::capture.output(print(brms::prior_summary(model))),
        collapse = '\n'
      ),
      provenance = list(
        engine = 'brms',
        version = as.character(utils::packageVersion('brms')),
        model_hash = digest::digest(model),
        data_hash = digest::digest(lapply(
          model$data[c(response, sort(predictors))],
          unname
        )),
        seed = seed,
        draw_ids = unname(result$ids),
        created_at = now_utc(),
        max_rhat = if (length(rhats)) max(rhats) else NULL,
        min_bulk_ess = if (length(ess)) min(ess) else NULL,
        divergences = div,
        diagnostics = 'R-hat and divergences are partial computational checks, not evidence of scientific adequacy.'
      ),
      capabilities = c(
        'conditional_expected_response',
        'conditional_future_observations',
        'coherent_scenario_draws'
      ),
      limitations = c(
        'No causal identification is inferred.',
        'No external-model refitting, sensitivity reweighting or automatic experiment design.',
        'This snapshot contains a finite scenario grid and posterior draw subset; probabilities have Monte Carlo error.'
      )
    ),
    'suppose_model_world'
  )
  validate_model_world(out)
  out
}

validate_model_world <- function(x) {
  check_seal(x, 'suppose_model_world')
  for (n in c(
    'title',
    'scope',
    'source',
    'assumptions',
    'response',
    'outcome_units',
    'varying',
    'formula',
    'family',
    'link'
  )) {
    check_text(x[[n]], n)
  }
  check_number(x$threshold, 'threshold')
  if (!is.null(x$lower_bound)) {
    check_number(x$lower_bound, 'lower_bound')
  }
  check_strings(x$structure, 'structure')
  check_strings(x$capabilities, 'capabilities')
  check_strings(x$limitations, 'limitations')
  if (
    !is.list(x$units) ||
      !length(x$units) ||
      anyDuplicated(names(x$units)) ||
      !x$varying %in% names(x$units)
  ) {
    abort_suppose('Invalid model-world units or varying predictor.', 'record')
  }
  for (unit in x$units) {
    check_text(unit, 'unit')
  }
  if (
    !is.numeric(x$training_range) ||
      length(x$training_range) != 2 ||
      !all(is.finite(x$training_range)) ||
      x$training_range[1] >= x$training_range[2]
  ) {
    abort_suppose('Invalid model-world fitting range.', 'record')
  }
  for (field in c(
    'engine',
    'version',
    'model_hash',
    'data_hash',
    'created_at',
    'diagnostics'
  )) {
    check_text(x$provenance[[field]], field)
  }
  check_count(x$provenance$seed, 'seed', 0, .Machine$integer.max)
  draw_ids <- x$provenance$draw_ids
  if (
    !is.numeric(draw_ids) ||
      anyNA(draw_ids) ||
      !all(is.finite(draw_ids)) ||
      any(draw_ids < 1 | draw_ids != floor(draw_ids)) ||
      anyDuplicated(draw_ids)
  ) {
    abort_suppose('Invalid model-world draw identifiers.', 'record')
  }
  n <- length(x$scenarios)
  if (
    n < 2 ||
      n > 101 ||
      !is.list(x$scenarios) ||
      !all(vapply(
        x$scenarios,
        function(r) {
          is.list(r) &&
            setequal(names(r), names(x$units)) &&
            all(vapply(
              r,
              function(v) is.numeric(v) && length(v) == 1 && is.finite(v),
              logical(1)
            ))
        },
        logical(1)
      ))
  ) {
    abort_suppose('Invalid model-world scenarios.', 'record')
  }
  settings <- world_scenarios(x)
  if (
    is.unsorted(settings[[x$varying]], strictly = TRUE) ||
      any(vapply(
        settings[setdiff(names(settings), x$varying)],
        function(v) length(unique(v)) != 1L,
        logical(1)
      ))
  ) {
    abort_suppose('Invalid model-world scenario ordering.', 'record')
  }
  if (
    !is.list(x$fitting_points) ||
      length(x$fitting_points) > 1000 ||
      !all(vapply(
        x$fitting_points,
        function(r) {
          is.list(r) &&
            setequal(names(r), c('x', 'y')) &&
            all(vapply(
              r,
              function(v) is.numeric(v) && length(v) == 1 && is.finite(v),
              logical(1)
            ))
        },
        logical(1)
      ))
  ) {
    abort_suppose('Invalid model-world fitting points.', 'record')
  }
  for (field in c('expected', 'future')) {
    a <- x[[field]]
    if (
      !is.list(a) ||
        length(a) < 50 ||
        length(a) > 1000 ||
        !all(vapply(
          a,
          function(r) is.numeric(r) && length(r) == n && all(is.finite(r)),
          logical(1)
        ))
    ) {
      abort_suppose('Invalid model-world prediction draws.', 'record')
    }
  }
  if (
    length(x$expected) != length(x$future) ||
      length(x$provenance$draw_ids) != length(x$expected)
  ) {
    abort_suppose('Model-world draw alignment is invalid.', 'record')
  }
  invisible(x)
}

#' Open a bundled model-world example
#'
#' These snapshots come from actual brms fits to the same synthetic coating data.
#' They open without brms, compilation or a model provider. `linear` uses a
#' straight-line mean; `curved` adds a quadratic term. Both use Gaussian noise.
#' `waiting` is a lognormal model of synthetic service waits, with positive,
#' skewed outcomes and multiplicative changes in typical waiting time.
#' Their predictions provide no evidence about real coatings. Rebuilding code
#' and data-generation seed are shipped in `model-worlds/build-model-worlds.R`.
#' @param example `"linear"`, `"curved"`, or `"waiting"`.
#' @return A validated `suppose_model_world` snapshot.
#' @export
#' @examples
#' world <- suppose_model_example('linear')
#' world$title
suppose_model_example <- function(example = c('linear', 'curved', 'waiting')) {
  example <- match.arg(example)
  path <- system.file(
    'model-worlds',
    paste0(example, '.json'),
    package = 'suppose'
  )
  x <- jsonlite::fromJSON(
    path,
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  validate_model_world(x)
  restore_record_types(x)
}

#' Retain a model snapshot as a simulation artifact
#'
#' This makes a model available to an inquiry without accepting an interpretation
#' or treating predictions as observations. Existing snapshots are deduplicated
#' by their content identifiers. The main claim remains unchanged.
#' @param x An elicitation record.
#' @param world A snapshot from [inspect_model()] or [suppose_model_example()].
#' @return An updated record containing the model snapshot.
#' @export
record_model_world <- function(x, world) {
  validate_record(x)
  validate_model_world(world)
  if (!world$id %in% vapply(x$model_worlds, function(w) w$id, character(1))) {
    x$model_worlds <- c(x$model_worlds, list(world))
  }
  x$model_implications <- x$model_implications %||% list()
  x$schema_version <- max(x$schema_version, 14L)
  validate_record(x)
  x
}

model_world_inquiry <- function(world) {
  elicitation_record(
    claim(
      paste('What world does', world$title, 'describe?'),
      author = 'Model walkthrough',
      scope = world$scope,
      unresolved = 'Which model implications need qualification or a direct check?'
    ),
    world$title
  )
}

#' Retain an external model and a reviewed implication
#'
#' The snapshot is a simulation artifact. Reviews record the author's position
#' on a claim and a proposed challenge; they do not accept a numerical prior,
#' count as observations, refit the external model, or freeze a prospective test.
#' @param x An elicitation record.
#' @param world A snapshot from [inspect_model()] or [suppose_model_example()].
#' @param claim A separately worded claim about the model's implications.
#' @param position One of `"accept"`, `"qualify"`, or `"challenge"`.
#' @param reason Why the author takes this position, including limitations.
#' @param challenge A measurement or observation that would probe the implication.
#' @param author Person who reviewed the implication.
#' @param reviewed Must be `TRUE` after reviewing the snapshot and claim.
#' @param scenario Row of the scenario table reviewed.
#' @param threshold Reviewed outcome threshold.
#' @param realization Shared posterior draw shown in the walkthrough.
#' @param comparison Optional comparable snapshot, retained with the review.
#' @return An updated record with an immutable snapshot and attributed review.
#' @export
record_model_implication <- function(
  x,
  world,
  claim,
  position = c('accept', 'qualify', 'challenge'),
  reason,
  challenge,
  author,
  reviewed = FALSE,
  scenario = 1L,
  threshold = world$threshold,
  realization = 1L,
  comparison = NULL
) {
  validate_record(x)
  validate_model_world(world)
  check_seal(claim, 'suppose_claim')
  position <- match.arg(position)
  for (n in c('reason', 'challenge', 'author')) {
    check_text(get(n), n)
  }
  if (!isTRUE(reviewed)) {
    abort_suppose(
      'Review the model consequences and wording before retaining this implication.'
    )
  }
  check_count(scenario, 'scenario', 1, length(world$scenarios))
  check_count(realization, 'realization', 1, length(world$expected))
  check_number(threshold, 'threshold')
  if (!is.null(comparison)) {
    validate_model_world(comparison)
    if (!world_comparable(world, comparison) || world$id == comparison$id) {
      abort_suppose(
        'A comparison requires distinct models with the same data, scenarios, response and units.'
      )
    }
    if (
      !comparison$id %in% vapply(x$model_worlds, function(w) w$id, character(1))
    ) {
      x$model_worlds <- c(x$model_worlds, list(comparison))
    }
  }
  if (!world$id %in% vapply(x$model_worlds, function(w) w$id, character(1))) {
    x$model_worlds <- c(x$model_worlds, list(world))
  }
  review <- seal(
    list(
      model_id = world$id,
      claim = claim,
      position = position,
      reason = reason,
      challenge = challenge,
      author = author,
      scenario = scenario,
      threshold = threshold,
      realization = realization,
      comparison_id = comparison$id,
      summary = world_summary(world, scenario, threshold),
      comparison_summary = if (is.null(comparison)) {
        NULL
      } else {
        world_summary(comparison, scenario, threshold)
      },
      created_at = now_utc()
    ),
    'suppose_model_implication'
  )
  x$model_implications <- c(x$model_implications, list(review))
  x$schema_version <- max(x$schema_version, 14L)
  validate_record(x)
  x
}

validate_model_worlds <- function(x) {
  worlds <- x$model_worlds
  reviews <- x$model_implications
  if (is.null(worlds) && is.null(reviews)) {
    return(invisible(x))
  }
  if (x$schema_version < 14 || !is.list(worlds) || !is.list(reviews)) {
    abort_suppose('Invalid model-world collections.', 'record')
  }
  lapply(worlds, validate_model_world)
  ids <- vapply(worlds, function(w) w$id, character(1))
  if (anyDuplicated(ids)) {
    abort_suppose('Duplicate model-world snapshots.', 'record')
  }
  for (r in reviews) {
    check_seal(r, 'suppose_model_implication')
    check_seal(r$claim, 'suppose_claim')
    for (n in c('model_id', 'reason', 'challenge', 'author')) {
      check_text(r[[n]], n)
    }
    if (
      !r$model_id %in% ids ||
        !r$position %in% c('accept', 'qualify', 'challenge')
    ) {
      abort_suppose(
        'Invalid model implication reference or position.',
        'record'
      )
    }
    w <- worlds[[match(r$model_id, ids)]]
    check_count(r$scenario, 'scenario', 1, length(w$scenarios))
    check_count(r$realization, 'realization', 1, length(w$expected))
    check_number(r$threshold, 'threshold')
    if (
      !isTRUE(all.equal(
        r$summary,
        world_summary(w, r$scenario, r$threshold),
        tolerance = 1e-12
      ))
    ) {
      abort_suppose(
        'The saved implication summary does not match its predictions.',
        'record'
      )
    }
    if (!is.null(r$comparison_id)) {
      if (!r$comparison_id %in% ids) {
        abort_suppose('Missing comparison model.', 'reference')
      }
      other <- worlds[[match(r$comparison_id, ids)]]
      if (
        !world_comparable(w, other) ||
          !isTRUE(all.equal(
            r$comparison_summary,
            world_summary(other, r$scenario, r$threshold),
            tolerance = 1e-12
          ))
      ) {
        abort_suppose('Invalid model comparison summary.', 'record')
      }
    } else if (!is.null(r$comparison_summary)) {
      abort_suppose('Unexpected comparison summary.', 'record')
    }
  }
  invisible(x)
}

world_matrix <- function(x, field) do.call(rbind, x[[field]])
world_scenarios <- function(x) {
  do.call(rbind, lapply(x$scenarios, as.data.frame))
}

world_summary <- function(
  x,
  index,
  threshold = x$threshold,
  validated = FALSE
) {
  if (!validated) {
    validate_model_world(x)
  }
  check_count(index, 'index', 1, length(x$scenarios))
  check_number(threshold, 'threshold')
  means <- world_matrix(x, 'expected')
  settings <- vapply(x$scenarios, function(s) s[[x$varying]], numeric(1))
  reference <- which.min(abs(settings - mean(x$training_range)))
  change <- means[, index] - means[, reference]
  e <- means[, index]
  y <- world_matrix(x, 'future')[, index]
  list(
    expected = unname(stats::quantile(e, c(0.05, 0.5, 0.95))),
    future = unname(stats::quantile(y, c(0.05, 0.5, 0.95))),
    expected_above = mean(e > threshold),
    future_above = mean(y > threshold),
    impossible = if (is.null(x$lower_bound)) NULL else mean(y < x$lower_bound),
    draws = length(y),
    reference_index = reference,
    change = unname(stats::quantile(change, c(0.05, 0.5, 0.95))),
    increase_fraction = mean(change > 0)
  )
}
