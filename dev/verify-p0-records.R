# Verify saved artifacts from both P0 browser scripts.
.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
read <- function(name) read_record(file.path("artifacts", name))
a <- read("p0-browser-before.json")
b <- read("p0-browser-record.json")
c <- read("p0-browser-reopened.json")
stopifnot(
  length(a$revisions) == 3L,
  length(b$revisions) == 7L,
  identical(json_data(b$revisions[1:3]), json_data(a$revisions)),
  identical(json_data(c), json_data(b)),
  length(b$model_references) == 1L,
  identical(
    b$model_references[[1]]$claim$wording,
    "The expected gain would justify a separate cost evaluation."
  )
)
e <- tail(b$revisions, 1)[[1]]
stopifnot(
  length(e$judgments) == 6L,
  is.null(e$judgments[[3]]$probabilities),
  identical(e$judgments[[3]]$reference_condition, 140L),
  identical(e$judgments[[4]]$quantity, "shape"),
  identical(e$judgments[[4]]$reference_condition, 170L),
  is.null(e$judgments[[5]]$probabilities),
  identical(e$judgments[[6]]$values, c(60L, 50L)),
  length(e$judgments[[6]]$issues) == 1L,
  is.null(e$acceptance),
  identical(e$candidate$id, tail(a$revisions, 1)[[1]]$candidate$id)
)
z <- check_expectations(b, linear = TRUE)
stopifnot(grepl(
  "cannot represent an interior peak",
  z$expectations[[4]]$explanation
))
cat(
  "Native save/reopen preserves prior IDs, all earlier acceptance, attributed expectations and the model reference exactly.\n"
)
{
  declined <- read("p0-declined.json")
  before <- read("p0-before-cancel.json")
  cancelled <- read("p0-after-cancel.json")
  retried <- read("p0-after-retry.json")
  corrected <- read("p0-after-correction.json")
  manual <- read("p0-unavailable-manual.json")
  stopifnot(
    length(declined$revisions) == 1L,
    length(before$revisions) == 2L,
    identical(json_data(before$revisions), json_data(cancelled$revisions)),
    length(retried$revisions) == 3L,
    length(corrected$revisions) == 4L,
    identical(json_data(retried$revisions[1:2]), json_data(before$revisions)),
    identical(
      tail(corrected$revisions, 1)[[1]]$assistance$correction_reason,
      "Keep the outcome and coordination constraint explicit."
    ),
    identical(
      tail(manual$revisions, 1)[[1]]$claim$target,
      "Elapsed days per completed work item"
    ),
    is.null(tail(manual$revisions, 1)[[1]]$candidate)
  )
  cat(
    "Decline/cancel retain exactly the earlier revisions; retry applies once; correction retains provenance; unavailable-model manual editing succeeds.\n"
  )
}

a <- read("p0-numeric-record.json")
b <- read("p0-numeric-reopened.json")
stopifnot(
  identical(json_data(a), json_data(b)),
  length(a$revisions) == 5L,
  !is.null(a$revisions[[5]]$acceptance)
)
cat("Numerical correction and explicit acceptance round-trip exactly.\n")
args <- commandArgs(TRUE)
if (length(args)) {
  result <- processx::run(
    args[1],
    c("inspect", normalizePath("artifacts/p0-browser-record.json"), "--json"),
    error_on_status = FALSE,
    env = c(
      R_PROFILE_USER = "/dev/null",
      R_ENVIRON_USER = "/dev/null",
      NO_COLOR = "1"
    )
  )
  stopifnot(result$status == 0L, !nzchar(result$stderr))
  inspected <- jsonlite::fromJSON(
    result$stdout,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  record <- read("p0-browser-record.json")
  stopifnot(
    length(inspected$judgments) == 6L,
    length(inspected$model_references) == 1L,
    identical(
      inspected$model_references[[1]]$id,
      record$model_references[[1]]$id
    ),
    identical(inspected$judgments[[6]]$values, c(60L, 50L))
  )
  writeLines(result$stdout, "artifacts/p0-cli-inspection.json")
  cat(
    "Isolated installed CLI reads schema 12, all six judgments and the exact model reference; stderr is empty.\n"
  )
}
