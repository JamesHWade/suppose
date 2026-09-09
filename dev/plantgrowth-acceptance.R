# Retrospective real-data acceptance example. No claim of a prospectively elicited prior.
if (dir.exists(".suppose/runtime-library")) {
  .libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
}
pkgload::load_all(quiet = TRUE)
folder <- "artifacts/plantgrowth"
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
author <- "Illustrative analyst (not the user)"
source <- "https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/PlantGrowth.html"
c <- claim(
  "Does treatment 2 increase mean dried plant weight by more than 0.5 weight units compared with control?",
  author,
  target = "Mean dried weight for trt2 minus ctrl",
  scope = "PlantGrowth experiment; ctrl and trt2; condition codes 0=ctrl, 1=trt2",
  units = "weight units",
  threshold = 0.5,
  assumptions = c(
    "Illustrative prior: both means have central 90% intervals [4,6], independent uncertainty",
    "Independent normally distributed plant measurements; SD fixed at 0.6 for both groups as an illustrative assumption, not estimated",
    "Physical weight units and measurement times are undocumented in R help"
  ),
  unresolved = "Published outcomes already examined. This is retrospective and does not establish causality or validate independence."
)
js <- lapply(0:1, function(condition) {
  judgment(
    condition,
    c(4, 6),
    c(.05, .95),
    units = "weight units",
    author = author,
    answer = "Illustrative central 90% interval for the mean: [4,6]",
    source = "Analyst-selected demonstration, not prospectively elicited",
    observed = "Public PlantGrowth outcomes already available",
    condition_units = "group code"
  )
})
p <- fit_prior(c, js, correlation = 0, batch_sd = c(.6, .6))
record <- record_revision(
  elicitation_record(c, "PlantGrowth retrospective example"),
  c,
  p,
  predict_prior(p, seed = 47),
  reason = "Retain explicitly illustrative prior for acceptance verification"
)
original <- record$revisions
raw <- datasets::PlantGrowth
keep <- raw$group %in% c("ctrl", "trt2")
rows <- which(keep)
data <- data.frame(
  observation_id = paste0("PlantGrowth-row-", rows),
  condition = as.character(raw$group[keep]),
  outcome = raw$weight[keep],
  batch = paste0("plant-", rows),
  specimen = paste0("plant-", rows),
  observed_at = "unknown"
)
utils::write.csv(data, file.path(folder, "measurements.csv"), row.names = FALSE)
obs <- import_observations(
  file.path(folder, "measurements.csv"),
  source = source,
  protocol = "Dried plant weights, 10 ctrl and 10 trt2; R datasets::PlantGrowth; source Dobson (1983). Independence assumed for demonstration; measurement times and physical units unavailable.",
  author = author,
  units = "weight units",
  role = "update",
  exposure = "explored"
)
record <- record_observations(
  record,
  obs,
  reason = "Retrospective published observations, not used to fit the illustrative prior"
)
write_record(record, file.path(folder, "prior-and-data.json"), overwrite = TRUE)
fit <- update_prior(p, obs, c(ctrl = 0, trt2 = 1), independent = TRUE)
record <- record_update(
  record,
  fit,
  reason = "Retrospective update under explicitly illustrative prior and fixed SD assumptions"
)
stopifnot(identical(record$revisions, original))
# Independent closed-form reference, separate from sequential implementation.
variance <- 1 / (1 / p$mean_sd^2 + 10 / .6^2)
means <- variance *
  (p$means /
    p$mean_sd^2 +
    c(
      mean(raw$weight[raw$group == "ctrl"]),
      mean(raw$weight[raw$group == "trt2"])
    ) *
      10 /
      .6^2)
stopifnot(
  isTRUE(all.equal(fit$posterior$means, means, tolerance = 1e-12)),
  isTRUE(all.equal(
    fit$posterior$covariance,
    as.numeric(diag(variance)),
    tolerance = 1e-12
  ))
)
write_record(record, file.path(folder, "updated-record.json"), overwrite = TRUE)
reopened <- read_record(file.path(folder, "updated-record.json"))
stopifnot(identical(json_data(record), json_data(reopened)))
ggplot2::ggsave(
  file.path(folder, "prior.png"),
  plot_prior(p),
  width = 8,
  height = 8,
  dpi = 120
)
ggplot2::ggsave(
  file.path(folder, "update.png"),
  plot_update(fit),
  width = 8,
  height = 5,
  dpi = 120
)
ggplot2::ggsave(
  file.path(folder, "intervals.png"),
  plot_update(fit, "intervals"),
  width = 8,
  height = 4,
  dpi = 120
)
writeLines(
  json_data(fit, pretty = TRUE),
  file.path(folder, "update-result.json")
)
cat(update_summary_text(fit), "\n")
