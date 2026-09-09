# Documentation refresh

9 September 2026. The README is reduced from 531 to 74 lines. A separate pkgdown
landing page introduces the package, with eight focused guides and a reference
index grouped by scientific task. The visual theme uses the sticker's plum,
lavender, and warm cream, system typography, and responsive layouts.

## Content

The guides cover a first qualitative inquiry, workbench setup and review,
prior consequences, a retrospective PlantGrowth update and sensitivity analysis,
a synthetic regression revision, research design, method boundaries, and CLI
use. The four numerical/record tutorials execute in the site build. The optional
research-design continuation was also run successfully against the regression
example with the local alloptr implementation. Installation and app-launch
snippets are explicitly unevaluated. A fresh installation of the complete UI
stack was not repeated.

The old README's stale statements about unavailable regression and persistent R
plots have been removed. History, permissions, provenance, prospective testing,
and method limitations are explained in the relevant guides. Historical project
notes remain in the repository, but are excluded from site search.

## Verification

- pkgdown 2.2.1 built the reference and all eight articles. Final article render
  completed without warnings. Article and reference metadata checks pass.
- R CMD check: 0 errors, 0 warnings, 0 notes. Tests: 1,162 assertions passed,
  with 56 snapshot tests skipped under the default On-CRAN condition.
- Browser verification covers 11 reader-facing pages at 1,360px and 390px widths,
  125 local links and anchors, figure loading and alternative text, guide menus,
  keyboard search, skip-to-content focus, and mobile navigation.
- Desktop homepage, mobile homepage, and statistical guide renders were inspected.
- `git diff --check` passes.

Reproduce with `Rscript dev/build-docs.R`. Serve `docs/` over HTTP, then run
`node dev/verify-docs.cjs http://127.0.0.1:3910` with Playwright and Chrome available.
Generated HTML, screenshots, and detailed logs remain local under `docs/` and
`artifacts/`; the scripts and this report are versioned.

## Hosting boundary

The preview is local. No public hosting or deployment workflow is configured.
`pkgdown::check_pkgdown()` still reports the intentionally unset canonical site
URL. The GitHub repository URL is recorded in DESCRIPTION; a documentation URL
should be added only when a hosting destination is selected.
