# Synthetic measurements demonstrate a revision loop, not independent evidence.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
source("tests/testthat/helper-regression.R")
folder <- "artifacts/regression"
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
f <- regression_fixture()
write_record(f$record, file.path(folder, "ready.json"), overwrite = TRUE)
utils::write.csv(
  f$data,
  file.path(folder, "predictor-measurements.csv"),
  row.names = FALSE
)
baseline_prior <- regression_test_prior(f, "temperature")
baseline <- fit_regression(f$record, baseline_prior, TRUE, TRUE, seed = 42)
first <- record_regression(
  f$record,
  baseline,
  "neither",
  "Synthetic analyst",
  "Duration-associated residuals challenge the temperature-only model",
  TRUE
)
write_record(
  first,
  file.path(folder, "baseline-reviewed.json"),
  overwrite = TRUE
)
extended_prior <- regression_prior(
  first,
  f$design$id,
  c("temperature", "duration"),
  location = 54,
  intercept_sd = 10,
  effect_sd = 20,
  noise_sd = 3
)
extended <- fit_regression(first, extended_prior, TRUE, TRUE, seed = 42)
final <- record_regression(
  first,
  extended,
  "extended",
  "Synthetic analyst",
  "Duration improves held-out prediction and removes the omitted-predictor pattern; the example is synthetic and causal meaning is not established",
  TRUE
)
write_record(final, file.path(folder, "revised.json"), overwrite = TRUE)
for (view in c("prior", "prediction", "residuals", "checks", "comparison")) {
  ggplot2::ggsave(
    file.path(folder, paste0(view, ".png")),
    plot_regression(extended, view),
    width = 9,
    height = if (view == "checks") 11 else 7,
    dpi = 110
  )
}
cat("Original and revised reviews:", length(final$regressions), "\n")
print(extended$comparison[c("extended_minus_baseline", "paired_se")])
print(vapply(extended$fits, function(f) f$noise$median, numeric(1)))
