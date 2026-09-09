# Run once to establish the package while preserving the design documents.
usethis::create_package(
  '.',
  fields = list(
    Title = 'Make Beliefs Explicit and Inspect Their Consequences',
    Description = paste(
      'Record attributed claims and elicited judgments, construct',
      'bounded normal prior models, inspect predictive consequences, and retain',
      'reviewed revisions in portable local bundles.'
    ),
    `Authors@R` = 'person("James", "Wade", role = c("aut", "cre"), email = "github@jameshwade.com")',
    Version = '0.0.0.9000'
  ),
  rstudio = FALSE,
  open = FALSE
)
usethis::use_mit_license('James Wade')
usethis::use_testthat(3)
for (p in c('cli', 'rlang', 'fs', 'withr', 'jsonlite', 'digest', 'Rapp')) {
  usethis::use_package(p)
}
for (p in c('shiny', 'bslib', 'shinychat', 'ellmer', 'pkgdown')) {
  usethis::use_package(p, 'Suggests')
}
usethis::use_package('R', type = 'Depends', min_version = '4.1.0')
usethis::use_news_md()
usethis::use_pkgdown()
for (f in c(
  'claim',
  'judgment',
  'prior',
  'predict',
  'record',
  'example',
  'workbench'
)) {
  usethis::use_r(f)
  usethis::use_test(f)
}
