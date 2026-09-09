.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
x <- read_record("artifacts/bed-conversation.json")
before <- read_record("artifacts/chat-walkthrough/reopened-conversation.json")
stopifnot(length(x$research_designs) == 1L, length(x$commitments) == 0L)
for (field in c(
  "revisions",
  "observations",
  "predictors",
  "regressions",
  "analyses"
)) {
  stopifnot(identical(
    suppose:::json_data(x[[field]]),
    suppose:::json_data(before[[field]])
  ))
}
e <- x$research_designs[[1]]
d <- e$design
stopifnot(
  e$choice == "T50x6",
  d$purpose == "decide",
  d$threshold == 15,
  identical(d$recommended, c("T50x6", "T70x6")),
  d$max_units == 6
)
candidates <- do.call(
  rbind,
  lapply(d$candidates, function(r) {
    as.data.frame(c(
      list(candidate_id = r$candidate_id),
      r$predictors,
      r[c("repeats", "cost", "feasible")]
    ))
  })
)
contrast <- do.call(rbind, lapply(d$target, as.data.frame))
recomputed <- design_regression(
  x,
  d$regression_id,
  candidates,
  contrast,
  purpose = d$purpose,
  threshold = d$threshold,
  max_units = d$max_units,
  rationale = d$rationale,
  preference = d$preference
)
stopifnot(isTRUE(all.equal(
  recomputed$candidates,
  d$candidates,
  tolerance = 1e-12
)))
stopifnot(any(vapply(
  d$model_checks,
  function(c) c$status == "simulation_uncertain",
  logical(1)
)))
print(data.frame(
  candidate = vapply(d$candidates, `[[`, character(1), "candidate_id"),
  benefit = vapply(d$candidates, `[[`, numeric(1), "benefit")
))
cat(
  "PASS: recomputed benefits, tied recommendations, preserved evidence/models/R analysis, and no prospective commitment.\n"
)
if (file.exists("artifacts/bed-reopened-conversation.json")) {
  reopened <- read_record("artifacts/bed-reopened-conversation.json")
  stopifnot(identical(
    suppose:::json_data(reopened$research_designs),
    suppose:::json_data(x$research_designs)
  ))
  cat("PASS: native reopening preserved the reviewed research plan exactly.\n")
}
