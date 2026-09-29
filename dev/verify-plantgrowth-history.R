.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
paths <- list.files(
  ".suppose/plantgrowth-acceptance-history",
  pattern = "^record.json$",
  recursive = TRUE,
  full.names = TRUE
)
stopifnot(length(paths) > 0)
path <- paths[which.max(file.info(paths)$mtime)]
history <- jsonlite::fromJSON(path, simplifyVector = FALSE)
state <- decode_inquiry_history(history$values$suppose)
x <- state$record
stopifnot(
  length(x$analyses) == 3L,
  length(x$updates) == 1L,
  length(x$revisions) == 2L
)
a <- x$analyses
stopifnot(
  a[[1]]$execution$session_id != a[[2]]$execution$session_id,
  a[[2]]$execution$session_id == a[[3]]$execution$session_id
)
stopifnot(isTRUE(a[[2]]$execution$fresh), !a[[3]]$execution$fresh)
text <- function(a) {
  paste(
    vapply(
      Filter(function(s) s$type != "plot", a$execution$segments),
      `[[`,
      character(1),
      "text"
    ),
    collapse = "\n"
  )
}
stopifnot(grepl("FALSE", text(a[[2]])), grepl("0.494", text(a[[3]])))
stopifnot(!grepl("pg[[:space:]]*<-", a[[3]]$execution$code))
stopifnot(any(vapply(
  a[[1]]$execution$segments,
  function(s) s$type == "plot",
  logical(1)
)))
x <- record_conversation(x, state$messages)
write_record(x, "artifacts/plantgrowth/browser-record.json", overwrite = TRUE)
stopifnot(identical(
  json_data(x),
  json_data(read_record("artifacts/plantgrowth/browser-record.json"))
))
writeLines(
  json_data(record_summary(x), pretty = TRUE),
  "artifacts/plantgrowth/cli-summary.json"
)
cat("Verified saved conversation", history$id, "\n")
cat(
  "Three analyses, one retained update, two unchanged prior revisions; fresh reopen and persistent follow-up verified.\n"
)
cat(update_summary_text(x$updates[[1]]$result), "\n")
