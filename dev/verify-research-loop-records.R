.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
before <- read_record("artifacts/bed-conversation.json")
after <- read_record("artifacts/research-loop-final.json")
reopened <- read_record("artifacts/research-loop-reopened.json")
for (field in c(
  "revisions",
  "observations",
  "predictors",
  "regressions",
  "analyses"
)) {
  stopifnot(identical(
    suppose:::json_data(after[[field]]),
    suppose:::json_data(before[[field]])
  ))
}
stopifnot(
  identical(after$research_designs[[1]], before$research_designs[[1]]),
  length(after$research_designs) == 2,
  length(after$regression_commitments) == 1,
  length(after$regression_test_data) == 3,
  length(after$regression_assessments) == 3,
  length(after$regression_sensitivities) == 1,
  identical(
    vapply(after$regression_assessments, `[[`, character(1), "status"),
    c("awaiting_outcomes", "within_prediction", "outside_prediction")
  )
)
for (field in c(
  "research_designs",
  "regression_commitments",
  "regression_test_data",
  "regression_assessments",
  "regression_sensitivities"
)) {
  stopifnot(identical(
    suppose:::json_data(after[[field]]),
    suppose:::json_data(reopened[[field]])
  ))
}
cat(
  "PASS: the R API validates the browser-created and natively reopened records; original evidence/models/planning review and all versioned research results are preserved.\n"
)
