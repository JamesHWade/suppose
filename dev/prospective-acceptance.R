# Synthetic lifecycle, with an explicitly simulated clock. No real evidence claim.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
source("tests/testthat/helper-prospective.R")
local({
  f <- prospective_fixture()
  folder <- "artifacts/prospective"
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  write_record(f$record, file.path(folder, "frozen.json"), overwrite = TRUE)
  ready <- record_observations(
    f$record,
    prospective_observations(f),
    "SYNTHETIC demonstration outcomes under a simulated clock"
  )
  write_record(ready, file.path(folder, "ready.json"), overwrite = TRUE)
  complete <- assess_test(
    ready,
    f$c$id,
    "Synthetic demonstration analyst",
    "SYNTHETIC full-cohort comparison",
    protocol_followed = TRUE
  )
  new_claim <- revise_claim(
    utils::tail(complete$revisions, 1)[[1]]$claim,
    wording = "Synthetic follow-up: reassess the strength difference in a new population.",
    author = "Synthetic demonstration analyst",
    reason = "Illustrate revision after assessment"
  )
  revised <- record_revision(
    complete,
    new_claim,
    reason = "Synthetic revision after assessment"
  )
  stopifnot(identical(revised$commitments, f$record$commitments))
  write_record(
    revised,
    file.path(folder, "assessed-and-revised.json"),
    overwrite = TRUE
  )
  partial <- record_observations(
    f$record,
    prospective_observations(f, rows = 1:3),
    "SYNTHETIC incomplete cohort"
  )
  partial <- assess_test(
    partial,
    f$c$id,
    "Synthetic demonstration analyst",
    "Before deadline",
    protocol_followed = TRUE
  )
  f$clock$now <- "2026-01-04T12:00:00Z"
  partial <- assess_test(
    partial,
    f$c$id,
    "Synthetic demonstration analyst",
    "After deadline",
    protocol_followed = TRUE
  )
  stopifnot(identical(
    vapply(partial$assessments, function(a) a$status, character(1)),
    c("awaiting_outcomes", "inconclusive")
  ))
  write_record(
    partial,
    file.path(folder, "missing-at-deadline.json"),
    overwrite = TRUE
  )
  ggplot2::ggsave(
    file.path(folder, "assessment.png"),
    plot_test(f$c, complete$assessments[[1]]),
    width = 8,
    height = 3,
    dpi = 150
  )
})
