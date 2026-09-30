# Conversation tests need a Deputy with the APIs the workbench uses.
skip_if_no_deputy <- function() {
  skip_if_not_installed("deputy", minimum_version = deputy_version)
}

# Workbench tests need the suggested packages suppose_app() requires.
skip_if_no_app <- function() {
  for (package in suppose_app_packages) {
    skip_if_not_installed(package)
  }
}
