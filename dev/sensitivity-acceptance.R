# Invented data and simulated dates demonstrate sensitivity, not real evidence.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
source("tests/testthat/helper-update.R")
source("tests/testthat/helper-sensitivity.R")
source("tests/testthat/helper-prospective.R")
folder <- "artifacts/sensitivity"
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
f <- sensitivity_fixture()
s <- sensitivity_analysis(f$record, f$update$id)
write_record(f$record, file.path(folder, "ready.json"), overwrite = TRUE)
write_record(
  record_sensitivity(f$record, s, "SYNTHETIC prior-data conflict sensitivity"),
  file.path(folder, "sensitive.json"),
  overwrite = TRUE
)
ggplot2::ggsave(
  file.path(folder, "sensitive-estimate.png"),
  plot_sensitivity(s),
  width = 5,
  height = 5,
  dpi = 150
)
stable <- sensitivity_fixture(
  rep(c(50, 58), each = 100),
  rep(c("low", "high"), each = 100)
)
s2 <- sensitivity_analysis(stable$record, stable$update$id)
write_record(
  record_sensitivity(
    stable$record,
    s2,
    "SYNTHETIC insensitive selected outputs"
  ),
  file.path(folder, "insensitive.json"),
  overwrite = TRUE
)
local({
  p <- prospective_fixture(updated = TRUE)
  difference <- p$c$prediction$upper
  x <- record_observations(
    p$record,
    prospective_observations(p, c(0, 0, difference, difference)),
    "SYNTHETIC original boundary outcome"
  )
  x <- assess_test(
    x,
    p$c$id,
    "Synthetic analyst",
    "SYNTHETIC boundary assessment",
    TRUE
  )
  s3 <- sensitivity_analysis(x, x$updates[[1]]$id)
  write_record(
    record_sensitivity(x, s3, "SYNTHETIC exploratory assessment comparison"),
    file.path(folder, "assessment-comparison.json"),
    overwrite = TRUE
  )
})
