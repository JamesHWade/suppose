.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
x <- read_record("artifacts/regression/browser-saved.json")
stopifnot(
  length(x$regressions) == 2L,
  x$regressions[[1]]$choice == "neither",
  x$regressions[[2]]$choice == "extended"
)
first <- x$regressions[[1]]$result
second <- x$regressions[[2]]$result
stopifnot(
  identical(first$spec$priors[[1]], second$spec$priors[[1]]),
  identical(first$fits[[1]]$posterior, second$fits[[1]]$posterior),
  identical(first$fits[[1]]$loo, second$fits[[1]]$loo),
  identical(first$spec$observation_ids, second$spec$observation_ids),
  second$comparison$extended_minus_baseline > 90,
  second$fits[[2]]$noise$median < 2,
  !is.null(x$regressions[[1]]$form_draft$context),
  !is.null(x$regressions[[2]]$form_draft$context)
)
# Reconstruct each pre-retention scientific basis from the immutable saved rows.
basis <- x
basis$conversation <- NULL
basis$regressions <- NULL
stopifnot(identical(suppose:::proposal_basis_id(basis), first$spec$basis_id))
basis$regressions <- x$regressions[1]
stopifnot(identical(suppose:::proposal_basis_id(basis), second$spec$basis_id))
check <- Filter(
  function(c) c$statistic == "largest_residual",
  second$fits[[2]]$checks
)[[1]]
stopifnot(
  check$status == "simulation_uncertain",
  check$mc_interval[1] < .975,
  check$mc_interval[2] > .975
)
prediction <- predict_regression(
  second,
  data.frame(temperature = 150, duration = 60)
)
cat("Two reviewed choices and their chat provenance survive download.\n")
cat(
  "Both pre-retention bases reconstruct; original scientific history is unchanged.\n"
)
cat(
  "Shared priors, baseline posterior, LOO scores and measurement IDs are identical.\n"
)
print(second$comparison[c("extended_minus_baseline", "paired_se")])
print(prediction$rows[[1]])
