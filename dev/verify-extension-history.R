.libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
pkgload::load_all(quiet = TRUE)
x <- read_record("artifacts/extension/browser-saved.json")
b <- read_record("artifacts/extension/ready.json")
stopifnot(
  length(x$model_extensions) == 1,
  length(x$sensitivities) == 1,
  identical(x$updates, b$updates),
  identical(x$revisions, b$revisions),
  x$model_extensions[[1]]$comparison$settings$effect_sd == 2,
  x$model_extensions[[1]]$form_draft$values$center == 60,
  identical(x$sensitivities[[1]]$result$components, "prior")
)
cat(
  "Verified both retained results, unchanged model history, and saved chat provenance.\n"
)
print(x$model_extensions[[1]]$form_draft$source_quote)
print(x$sensitivities[[1]]$form_draft$source_quote)
