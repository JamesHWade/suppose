# Developing Suppose

Source is maintained in the private [GitHub repository](https://github.com/JamesHWade/suppose).
The R API owns statistical operations and record integrity; Shiny and the CLI
call that API. Keep tests independent of model credentials.

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

## Layout

`inquiry_server()` composes the conversation workbench from controllers that
share one set of reactive values: `R/inquiry-agent-lifecycle.R` (switching,
rebuilding and closing the agent), `R/inquiry-history-binding.R` (the chat,
saved conversations, download and reopen), `R/inquiry-editor.R` (the record
editor) and `R/inquiry-forms.R` (the forms in the drawer). Stylesheets and
scripts are files in `inst/www/`, attached with `suppose_dependency()`.
Working notes, backlogs and reviews live in `dev/notes/`; written evidence
reports stay in `artifacts/` beside the ignored outputs of the `dev/` scripts.

## Versioning

Suppose stays on a `0.0.0.9xxx` development version until it goes to CRAN,
which will be 0.1.0. Don't raise the major, minor or patch version to mark a
milestone, and don't add a release heading to `NEWS.md`: new entries go under
`# suppose (development version)`. Until then, R CMD check's "No news entries
found" NOTE for `NEWS.md` is expected.

## Documentation

The README is a short package introduction. `pkgdown/index.md` is the site landing
page; `vignettes/` holds task-oriented guides. These site-only articles
are excluded from the R package build. Numerical tutorial chunks execute during
the site build; app launch and installation snippets are explicitly unevaluated.
Keep synthetic and retrospective examples labeled, and put method restrictions
beside the result they qualify.

Run `Rscript dev/build-docs.R` to build the site in `docs/`. The script uses the
project runtime library when available. Serve that directory locally to inspect
navigation, search, figures, and mobile layouts. Generated HTML stays out of Git.

The repository is private and no public documentation host is configured.
`pkgdown::check_pkgdown()` therefore still reports the missing canonical site URL;
article and reference indexes can be checked separately. Configure the canonical
URL only after a hosting destination is agreed. Do not publish private-repository
content as a side effect of a documentation build.

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
