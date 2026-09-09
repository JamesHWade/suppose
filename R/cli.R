#' Install the package's Rapp launcher
#'
#' For an isolated package environment, use the external `ir tool install`
#' command instead. This helper installs a launcher using the current R library.
#' @param destdir Destination directory for the executable launcher.
#' @return The result of [Rapp::install_pkg_cli_apps()], invisibly.
#' @export
install_suppose_cli <- function(destdir = NULL) {
  invisible(Rapp::install_pkg_cli_apps("suppose", destdir = destdir))
}

cli_record_summary <- function(x) {
  validate_record(x)
  e <- utils::tail(x$revisions, 1)[[1]]
  list(
    record_id = x$record_id,
    revisions = length(x$revisions),
    latest = e$prediction$summary,
    interpretation = plain(e$claim),
    judgments = plain(e$judgments),
    model_references = plain(x$model_references),
    review = plain(e$acceptance),
    observations = plain(x$observations),
    updates = plain(x$updates),
    analyses = plain(x$analyses),
    commitments = plain(x$commitments),
    assessments = plain(x$assessments),
    sensitivities = plain(x$sensitivities),
    model_extensions = plain(x$model_extensions),
    predictor_datasets = plain(x$predictors),
    regressions = plain(x$regressions),
    research_designs = plain(x$research_designs)
  )
}
