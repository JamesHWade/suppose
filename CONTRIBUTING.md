# Developing Suppose

Package setup is recorded in `dev/setup.R`: usethis created metadata, dependency
entries, the testthat edition-3 layout, R/test files, NEWS, license, pkgdown, and
build exclusions. Author details use the local Git identity. Existing design
notes and artwork were preserved. There is no Git repository or configured
remote yet, so no CI workflow, PR, or publication has been created.

```r
pkgload::load_all()
devtools::document()
devtools::test()
rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")
```

Run `air format .` before documentation and checks. `Rscript dev/numerical-probe.R`
compares the supported model to independent analytic and Monte Carlo references.
Tests must work without model credentials. Put statistical behavior in the core
API; keep Shiny and CLI code as callers of those operations.

Public APIs put the domain object first, require attribution and consequential
assumptions explicitly, and return new objects rather than mutating accepted
ones. Constructors retain incomplete meaning. Fitting is narrower than storage:
unsupported answers stay visible instead of receiving invented numerical content.
Conditions inherit `suppose_error` and a more specific class such as
`suppose_units`, `suppose_judgment`, `suppose_fit`, `suppose_stale`, or
`suppose_integrity`; contextual fields remain available to callers. Use cli
markup and strip ANSI styling when displaying a condition in the browser.

Build the local documentation with `pkgdown::build_site(preview = FALSE)`.
The reference index and examples should build successfully. `pkgdown::check_pkgdown()`
currently reports the missing canonical site URL because hosting has not been
established; do not invent a published URL to silence it. Set the real URL in
DESCRIPTION and `_pkgdown.yml` when hosting exists.

Development tools such as pak, pkgload, pkgbuild, rcmdcheck, and pkgdown do not
belong in runtime Imports unless the package actually uses them. Use usethis CI
and release helpers when a remote or release workflow is established.

The conversation R integration is validated against the Deputy revision in
`Config/suppose/verified-deputy-revision`, installed locally in
`.suppose/runtime-library`. Add that directory to `.libPaths()` before loading
Suppose. This also uses Deputy's S7 permissions, usage, and context settings.
Run `Rscript dev/plantgrowth-acceptance.R` to regenerate the retrospective
real-data example. `dev/run-plantgrowth-app.R` opens the example on port 3900;
`dev/run-lab-app.R` serves the ordinary workbench on port 3899.
