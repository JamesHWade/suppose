# Workbench tests need the suggested packages suppose_app() requires.
skip_if_no_app <- function() {
  for (package in suppose_app_packages) {
    skip_if_not_installed(package)
  }
}
