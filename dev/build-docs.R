# Build evaluated guides and the reference site without launching the app.
if (dir.exists(".suppose/runtime-library")) {
  .libPaths(c(normalizePath(".suppose/runtime-library"), .libPaths()))
}
pkgdown::build_site(preview = FALSE, new_process = FALSE, install = TRUE)
