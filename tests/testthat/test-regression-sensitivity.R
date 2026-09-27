test_that("powered posteriors match the original fit and the full joint log density", {
  f <- research_design_fixture()
  e <- research_regression(f$record, f$regression_id)
  fit <- regression_selected_fit(e)
  prior <- tail(e$result$spec$priors, 1)[[1]]
  design <- regression_model_matrix(
    list(predictors = e$result$predictor_values),
    e$result$spec$transforms,
    fit$terms[-1]
  )
  y <- as.numeric(unlist(e$result$observed))
  original <- regression_power_posterior(design, y, prior, 1, 1)
  expect_equal(original$mean, fit$posterior$mean)
  expect_equal(original$v, do.call(rbind, fit$posterior$v))
  expect_equal(original$shape, fit$posterior$shape)
  expect_equal(original$rate, fit$posterior$rate)
  # Compare kernels at two arbitrary states; the normalizing constant cancels.
  joint <- function(beta, variance, alpha, weight) {
    log_prior <- -(prior$shape + 1 + length(beta) / 2) *
      log(variance) -
      (prior$rate + sum((beta - prior$mean)^2 / prior$v_diagonal) / 2) /
        variance
    log_lik <- -length(y) /
      2 *
      log(variance) -
      sum((y - drop(design %*% beta))^2) / (2 * variance)
    alpha * log_prior + weight * log_lik
  }
  for (weights in list(c(0.8, 1), c(1, 0.8), c(1.25, 1), c(1, 1.25))) {
    post <- regression_power_posterior(design, y, prior, weights[1], weights[2])
    kernel <- function(beta, variance) {
      -(post$shape + 1 + length(beta) / 2) *
        log(variance) -
        (post$rate +
          drop(t(beta - post$mean) %*% solve(post$v) %*% (beta - post$mean)) /
            2) /
          variance
    }
    b1 <- c(53, 3, 14)
    b2 <- c(56, 2, 17)
    expect_equal(
      joint(b1, 3, weights[1], weights[2]) -
        joint(b2, 6, weights[1], weights[2]),
      kernel(b1, 3) - kernel(b2, 6)
    )
  }
  expect_snapshot(
    error = TRUE,
    regression_power_posterior(design, y, prior, 0.1, 1)
  )
})

test_that("sensitivity holds designs fixed and separates utility from model assumptions", {
  skip_if_not_installed("alloptr")
  f <- research_design_fixture()
  d <- research_design_test_preview(
    f,
    purpose = "decide",
    threshold = 7,
    preference = "B must gain seven outcome units to offset its burden"
  )
  x <- record_research_design(
    f$record,
    d,
    "replicated",
    "Reviewer",
    "Review plan",
    TRUE
  )
  plan <- x$research_designs[[1]]
  before <- x
  withr::local_seed(98)
  rng <- .Random.seed
  s <- sensitivity_regression(
    x,
    f$regression_id,
    f$contrast,
    design_id = plan$id,
    utility_thresholds = c(0, 7, 1000),
    draws = 200
  )
  expect_identical(.Random.seed, rng)
  expect_equal(
    s$variants[[1]]$design$candidates[[1]]$benefit,
    d$candidates[[1]]$benefit
  )
  utility <- Filter(function(v) v$component == "utility", s$variants)
  expect_identical(utility[[1]]$posterior, s$variants[[1]]$posterior)
  expect_identical(utility[[1]]$contrast, s$variants[[1]]$contrast)
  expect_length(utility[[3]]$design$recommended, 0)
  expect_identical(
    vapply(utility[[1]]$design$candidates, `[[`, numeric(1), "cost"),
    f$candidates$cost
  )
  x <- record_regression_sensitivity(
    x,
    s,
    "Reviewer",
    "Inspect assumption dependence",
    TRUE
  )
  expect_identical(x$regressions, before$regressions)
  expect_identical(x$research_designs, before$research_designs)
  path <- tempfile()
  write_record(x, path)
  expect_identical(json_data(read_record(path)), json_data(x))
})

test_that("a small prior-sensitive case changes rankings while an informed case stays stable", {
  skip_if_not_installed("alloptr")
  small <- regression_fixture(6)
  spec <- regression_prior(
    small$record,
    small$design$id,
    c("temperature", "duration"),
    location = 54,
    intercept_sd = 10,
    effect_sd = 3,
    noise_sd = 3
  )
  fit <- fit_regression(small$record, spec, TRUE, TRUE, draws = 200)
  x <- record_regression(
    small$record,
    fit,
    "extended",
    "Reviewer",
    "Small synthetic prior-sensitive case",
    TRUE
  )
  id <- x$regressions[[1]]$id
  candidates <- data.frame(
    candidate_id = c("low", "high"),
    temperature = c(140, 160),
    duration = 60,
    repeats = 2,
    cost = c(0, 4.3),
    feasible = TRUE
  )
  contrast <- data.frame(temperature = c(140, 160), duration = 60)
  design <- design_regression(
    x,
    id,
    candidates,
    contrast,
    rationale = "Invented squared-outcome costs chosen to expose a close decision"
  )
  x <- record_research_design(
    x,
    design,
    "low",
    "Reviewer",
    "Review cost assumption",
    TRUE
  )
  s <- sensitivity_regression(
    x,
    id,
    contrast,
    components = "prior",
    design_id = x$research_designs[[1]]$id,
    draws = 200
  )
  expect_identical(s$variants[[1]]$design$recommended, "low")
  expect_identical(s$variants[[2]]$design$recommended, "high")
  expect_equal(s$variants[[2]]$change$recommendation_changed, TRUE)
  expect_equal(s$variants[[2]]$review_flag, TRUE)
  expect_equal(
    vapply(s$variants[[2]]$design$candidates, `[[`, numeric(1), "cost"),
    c(0, 4.3)
  )

  informed <- regression_fixture(120)
  fit <- fit_regression(
    informed$record,
    regression_test_prior(informed),
    TRUE,
    TRUE,
    draws = 200
  )
  x <- record_regression(
    informed$record,
    fit,
    "extended",
    "Reviewer",
    "Informed case",
    TRUE
  )
  id <- x$regressions[[1]]$id
  design <- design_regression(
    x,
    id,
    candidates,
    contrast,
    rationale = "The same fixed settings and costs with more informative data"
  )
  x <- record_research_design(x, design, "low", "Reviewer", "Review", TRUE)
  s <- sensitivity_regression(
    x,
    id,
    contrast,
    design_id = x$research_designs[[1]]$id,
    draws = 200
  )
  expect_equal(
    vapply(s$variants, function(v) v$change$recommendation_changed, logical(1)),
    rep(FALSE, 5)
  )
  expect_equal(
    vapply(s$variants, `[[`, logical(1), "review_flag"),
    rep(FALSE, 5)
  )
})

test_that("orthogonal predictors with signed zero covariance remain portable", {
  f <- regression_fixture(40)
  fit <- fit_regression(
    f$record,
    regression_test_prior(f),
    TRUE,
    TRUE,
    draws = 200
  )
  x <- record_regression(
    f$record,
    fit,
    "extended",
    "Reviewer",
    "Orthogonal design",
    TRUE
  )
  s <- sensitivity_regression(
    x,
    x$regressions[[1]]$id,
    data.frame(temperature = c(140, 160), duration = 60),
    draws = 200
  )
  x <- record_regression_sensitivity(
    x,
    s,
    "Reviewer",
    "Check portable matrix",
    TRUE
  )
  path <- tempfile()
  write_record(x, path)
  expect_identical(json_data(read_record(path)), json_data(x))
  expect_equal(do.call(rbind, s$variants[[1]]$posterior$v)[1, 3], 0)
})
