# Verify an actual installed launcher, without a user profile or user library.
# Usage: Rscript dev/verify-cli.R /path/to/isolated/bin/suppose
pkgload::load_all(quiet = TRUE)
launcher <- commandArgs(trailingOnly = TRUE)[[1]]
stopifnot(file.exists(launcher))
workspace <- tempfile("suppose cli verification ")
dir.create(workspace)
numeric_path <- file.path(workspace, "numerical record.json")
qualitative_path <- file.path(workspace, "qualitative record.json")
run <- function(args) {
  processx::run(
    launcher,
    args,
    error_on_status = FALSE,
    env = c(
      R_PROFILE_USER = "/dev/null",
      R_ENVIRON_USER = "/dev/null",
      NO_COLOR = "1"
    )
  )
}
created <- run(c("demo", numeric_path, "--seed", "47"))
stopifnot(created$status == 0L, !nzchar(created$stdout), nzchar(created$stderr))
x <- read_record(numeric_path)
prediction <- run(c("predict", numeric_path, "--seed", "7", "--n", "200"))
stopifnot(prediction$status == 0L, !nzchar(prediction$stderr))
received <- jsonlite::fromJSON(prediction$stdout)
reference <- predict_prior(
  tail(x$revisions, 1)[[1]]$candidate,
  seed = 7,
  n = 200
)
stopifnot(
  isTRUE(all.equal(received$draws, reference$draws)),
  isTRUE(all.equal(received$summary, reference$summary))
)
missing_seed <- run(c("predict", numeric_path))
stopifnot(
  missing_seed$status != 0L,
  !nzchar(missing_seed$stdout),
  nzchar(missing_seed$stderr)
)
overwrite <- run(c("demo", numeric_path))
stopifnot(
  overwrite$status != 0L,
  identical(
    suppose:::json_data(read_record(numeric_path)),
    suppose:::json_data(x)
  )
)
qualitative <- read_record("artifacts/quality-live-demand.json")
write_record(qualitative, qualitative_path)
inspection <- run(c("inspect", qualitative_path, "--json"))
stopifnot(inspection$status == 0L, !nzchar(inspection$stderr))
inspected <- jsonlite::fromJSON(inspection$stdout)
claim <- tail(qualitative$revisions, 1)[[1]]$claim
stopifnot(
  identical(inspected$interpretation$wording, claim$wording),
  identical(inspected$interpretation$expectations, claim$expectations),
  identical(inspected$interpretation$unresolved, claim$unresolved)
)
unsupported <- run(c("predict", qualitative_path, "--seed", "47"))
stopifnot(
  unsupported$status != 0L,
  !nzchar(unsupported$stdout),
  grepl("no numerical candidate", unsupported$stderr, fixed = TRUE)
)
cat(
  "Installed ir launcher: numerical draws and summaries match R; qualitative meaning matches the live saved record.\n"
)
cat(
  "Paths with spaces, stderr/stdout separation, overwrite refusal, missing seed, and absent numerical model verified.\n"
)
cat(
  "R user profile and environment files disabled; launcher isolates its library with R_LIBS_USER=NULL.\n"
)
unlink(workspace, recursive = TRUE)
