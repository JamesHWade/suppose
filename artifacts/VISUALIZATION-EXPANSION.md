# Visualization expansion

Implemented September 8, 2026.

## Available now

- `plot_prior()` returns editable ggplot2 mean/contrast plots, a patchwork overview,
  ggdist central-90% intervals, or Plotly widgets. Predictions must match the prior.
- Native prior cards and the Record drawer expose Densities, Intervals, and Explore.
  Stored analytic parameters regenerate the views after application restart.
- Interactive contrasts support hover, zoom, and legend visibility. Numerical
  summaries remain available as text. Colour and line style distinguish curves.
- `dev/visualization-examples.R` generates PNG, SVG, PDF, interactive HTML, a gt
  table, and a Leaflet map using R's built-in quakes dataset.
- Local gallery: http://127.0.0.1:3899/visualization-examples/index.html
- Existing restored prior: http://127.0.0.1:3899/?shinychat_conversation_id=c_001a080dd066226e968e956

The gallery is served by the development launcher only. Leaflet tiles need a
network connection; the earthquake points are bundled. Prior judgments in the
gallery and the adhesive conversation are explicitly fictional.

## Validation

- Full suite: 478 passing assertions, no failures/warnings/skips (viz-full-tests.log).
- R CMD check: 0 errors, 0 warnings, 0 notes (viz-check-final.log), with the system
  clock check disabled as in earlier local checks. A prototype string's non-ASCII
  warning was corrected before the final check.
- Air formatting and Jarl checks pass for the changed R files and examples.
  A broad Jarl scan still reports pre-existing findings in unrelated files.
- pkgdown site built successfully (viz-docs-final.log). The separate metadata
  checker reports a pre-existing missing public URL; no public deployment URL
  has been invented.
- Browser: restored adhesive conversation shows static/interval/interactive views.
  Toggling the Future measurements legend changes trace visibility to legendonly.
  At 390px viewport the document remains 390px wide with no Shiny output errors.
  Final screenshot: viz-interactive-mobile-final.png.
- Gallery: one Plotly widget, one rendered gt table, 1000 Leaflet markers and
  loaded map tiles. Zoom-in was exercised in the browser.
- Explicit worker test now captures ggplot2, patchwork, and a follow-up revision.
  The earlier conditional ggplot2 check had not run before package installation;
  that earlier pass count was not evidence of ggplot2 support.

## Runtime boundary

The local R worker spike remains in R/inquiry-r.R for behavioral validation.
It is not injected into the app. Deputy's current native R execution tool still
returns text. Stateful general R execution, image results for both model and
chat, rich-result offloading, and durable arbitrary widgets/tables are assigned
to the existing Deputy task. Merely installing a package does not establish that
its objects render through that execution tool. The built-in prior widgets use
Suppose's native Shiny output binding and are independently working now.

## Package versions and references

Exact installed versions are in visualizations/versions.csv.

- ggplot2: https://ggplot2.tidyverse.org/
- patchwork: https://patchwork.data-imaginist.com/
- ggdist: https://mjskay.github.io/ggdist/
- htmlwidgets: https://www.htmlwidgets.org/
