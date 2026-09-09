research_design_fixture <- function() {
  f <- regression_fixture(12)
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
    "Exploratory model; observational and diagnostic limits remain",
    TRUE
  )
  list(
    record = x,
    regression_id = x$regressions[[1]]$id,
    candidates = data.frame(
      candidate_id = c("low", "middle", "high", "replicated", "unavailable"),
      temperature = c(140, 150, 160, 160, 170),
      duration = 60,
      repeats = c(1, 1, 1, 6, 1),
      cost = 0,
      feasible = c(TRUE, TRUE, TRUE, TRUE, FALSE)
    ),
    contrast = data.frame(temperature = c(140, 160), duration = 60)
  )
}

research_design_test_preview <- function(f, ...) {
  design_regression(
    f$record,
    f$regression_id,
    f$candidates,
    f$contrast,
    rationale = "Synthetic independent batches; zero experiment cost under a six-unit budget",
    ...
  )
}

research_design_test_values <- function(f) {
  csv <- function(x) {
    paste(
      capture.output(utils::write.csv(x, row.names = FALSE, quote = FALSE)),
      collapse = "\n"
    )
  }
  list(
    regression_id = f$regression_id,
    candidates_csv = csv(f$candidates),
    contrast_csv = csv(f$contrast),
    purpose = "estimate",
    threshold = 0,
    max_units = 6,
    rationale = "Synthetic independent batches; zero experiment cost under a six-unit budget",
    preference = ""
  )
}
