# Model-world walkthrough acceptance

The first external-model slice lets users begin with a brms model or a provided
example, inspect its conditional consequences, and retain an independently
worded interpretation and a proposed challenge. Models remain simulation
artifacts; interpretation reviews neither add observations nor freeze tests.

## Delivered

- `inspect_model()` supports bounded univariate Gaussian and lognormal MCMC
  models with numeric formula terms and explicit scenario grids. It preserves
  the fitted object and caller RNG state and records model/data fingerprints,
  formula, priors, units, scientific context, draw IDs and computational checks.
- Three genuine brms examples open from saved predictions without brms, Stan
  compilation or a provider: straight-line and curved coating models on the same
  synthetic data, and a positive, skewed waiting-time model. Their complete
  rebuilding script is shipped with the package and downloadable in the app.
- Native range controls connect exact scenario rows and coherent posterior
  realizations to pointwise intervals, individual outcomes, threshold fractions,
  conditional changes and compatible model comparisons. The app identifies
  extrapolation and outcomes below a supplied physical bound.
- Starting models can enter a conversation before an interpretation is accepted.
  Reviews retain the exact model(s), scenario, threshold, realization, claim,
  reviewer, position, rationale and proposed challenge. Editing consequential
  fields invalidates review; modal reopening preserves local draft text.
- Schema 14 retains snapshots and reviews in portable JSON and native history.
  A reopened record restores its reviewed scenario without restoring acceptance
  into the editor. Independent browser sessions do not share edits or reviews.

## Evidence

`dev/verify-model-world-adapter.R` compares all three models with direct brms
predictions and independently reconstructs their expected responses from
coefficient draws. The lognormal reconstruction includes the variance-dependent
mean adjustment. It checks caller RNG and fit preservation, rejected unsupported
inputs, and the actual browser-exported record. Expected-response reconstruction
agrees within 1e-10; retained simulations agree with direct brms calls.

The provided fits used brms 2.23.0, four chains, 2,000 iterations per chain with
1,000 warmup iterations, and fixed seeds. Maximum R-hat values are approximately
1.0030, 1.0011 and 1.0040; all have zero divergences and minimum bulk ESS above
2,100. These are limited computational checks, not evidence of scientific
adequacy. A separate run of the shipped rebuilding script in an isolated directory
reused the genuine cached fits and reproduced every retained prediction.

`dev/verify-model-worlds.cjs` passes the provider-free desktop and mobile journey:
compare models, extrapolate, step a shared draw, use native arrow keys, tab without
changing a selection, invalidate stale review, preserve an editor draft, retain,
download, hand a challenge to the composer, reopen exact records, inspect the
waiting model, and verify session isolation. Final mobile figures were inspected
visually. JavaScript errors and visible Shiny output errors are absent.

`dev/verify-model-world-history.cjs` passes an actual connected discussion using
`read_inquiry`, with explicit central 90% intervals, synthetic provenance and
extrapolation limits. No interpretation is created by that discussion. A human
review then survives native URL reopening with exact models, reviews, main claim
and conversation length, and an unchecked review editor.

The evaluated pkgdown site passes 13 desktop/mobile pages and 158 local links and
anchors, including all ten guides. Figures, alternative text, search, skip links
and navigation pass. Air and focused Jarl checks pass. The final package-check suite
passed 1,550 assertions, without failures, warnings or skips.

Final R CMD check: 0 errors, 0 warnings, 0 notes. The optional
`pkgdown::check_pkgdown()` metadata check cannot pass until a published site URL
is configured; the private project has no configured site URL. The site build
and browser checks above pass locally.

## Boundaries

This is SUP-038 and a partial implementation of SUP-017. General R simulators,
Stan/tidymodels adapters, group-level models, special prediction terms, prior-only
fits, arbitrary refitting, generalized sensitivity and external-model experiment
design remain separate work. The supported family does not establish causality.
Pointwise intervals are not simultaneous coverage for a whole curve or experiment.
Finite-sample probability estimates retain Monte Carlo uncertainty.

Saved snapshots include scientific context, predictions and, for single-predictor
models, up to 1,000 fitting-data points. They contain no executable fitted model.
The examples are synthetic and establish no fact about real coatings or services.
Intended-scientist acceptance under SUP-011 remains open.
