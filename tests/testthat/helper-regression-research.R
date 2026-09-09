regression_research_fixture <- function(rule = "joint_outcomes") {
  clock <- new.env(parent = emptyenv())
  clock$now <- "2026-01-01T12:00:00Z"
  testthat::local_mocked_bindings(
    now_utc = function() clock$now,
    .env = parent.frame()
  )
  f <- research_design_fixture()
  planned <- data.frame(
    observation_id = paste0("future-", 1:4),
    condition = c("A", "A", "B", "B"),
    temperature = c(140, 140, 160, 160),
    duration = 60
  )
  p <- plan_regression_test(
    f$record,
    f$regression_id,
    planned,
    "future:regression",
    "randomized-v1",
    "2026-01-03T12:00:00Z",
    "Temperature mean contrast",
    "intervention",
    "Randomized independent preparations at a fixed collection time",
    rule
  )
  x <- commit_regression_test(
    f$record,
    p,
    "Reviewer",
    "Challenge the fitted predictions",
    TRUE,
    TRUE
  )
  clock$now <- "2026-01-02T12:00:00Z"
  data <- planned
  data$outcome <- p$prediction$location
  data$batch <- data$observation_id
  data$specimen <- data$observation_id
  data$observed_at <- "2026-01-02T10:00:00Z"
  list(
    record = x,
    before = f$record,
    id = x$regression_commitments[[1]]$id,
    plan = p,
    data = data,
    clock = clock,
    design = f
  )
}

regression_research_attach <- function(
  f,
  data = f$data,
  supersedes = NULL,
  ...
) {
  record_regression_test_data(
    f$record,
    f$id,
    data,
    "future:regression",
    "randomized-v1",
    "MPa",
    c(temperature = "degC", duration = "minutes"),
    "Collector",
    "Reviewed future measurements",
    TRUE,
    supersedes,
    ...
  )
}
