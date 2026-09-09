# Invented measurements demonstrate a model extension, not real evidence.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
source("tests/testthat/helper-update.R")
source("tests/testthat/helper-sensitivity.R")
folder <- "artifacts/extension"
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
f <- sensitivity_fixture(
  rep(c(50, 58), each = 10),
  rep(c("low", "high"), each = 10)
)
write_record(f$record, file.path(folder, "ready.json"), overwrite = TRUE)
comparison <- compare_extension(
  f$record,
  "Duration",
  "minutes",
  60,
  10,
  plausible_lower = 0,
  plausible_upper = 100
)
retained <- record_extension(
  f$record,
  comparison,
  "Synthetic analyst",
  "SYNTHETIC duration comparison",
  reviewed = TRUE
)
write_record(retained, file.path(folder, "reviewed.json"), overwrite = TRUE)
ggplot2::ggsave(
  file.path(folder, "comparison.png"),
  plot_extension(comparison),
  width = 8,
  height = 7,
  dpi = 120
)
print(comparison$matched_contrast)
