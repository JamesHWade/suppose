# Bayesian regression revision: verification and limits

Completed 2026-09-08 as SUP-028. Suppose now supports one bounded fitted-model
revision cycle: attach measured predictors, preview priors, fit unknown-noise
regression, inspect posterior predictions and discrepancies, add a predictor,
compare predictive performance, and retain a reviewed choice without replacing
earlier evidence or model reviews.

## Delivered behavior

- Predictor tables or CSV files join existing outcomes by observation ID, with
  explicit units, source and evidence references. Missing outcomes, duplicate
  IDs, unsupported roles and repeated batch/specimen pairs cannot silently enter
  a fit.
- One or two numeric predictors use a proper normal/inverse-gamma prior and
  exact inference. Coefficients share uncertainty through the unknown variance;
  this is an explicitly new model, not a conversion of the earlier fixed-noise
  model. Predictor coding and common priors remain fixed during comparisons.
- Prior and posterior plots distinguish mean uncertainty from new-outcome
  uncertainty. Joint posterior simulations check location, spread, extreme
  residuals and residual patterns against all attached predictors. Monte Carlo
  intervals distinguish clear discrepancies from uncertain screening results.
- Exact leave-one-out refits compare both models on identical observations.
  Pointwise scores, their summed difference and paired standard error are saved.
- The actual `draft_regression` chat tool populates the form and previews priors.
  Fitting and retaining require human review. Manual edits, pending drafts,
  reviewed settings and quoted drafting context survive native restoration.
- Portable records and CLI inspection retain both reviews and their provenance.
  New-case prediction provides exact marginal intervals and range warnings.

## Live acceptance evidence

The synthetic 40-observation example deliberately omitted duration from the
initial temperature-only model. Two real chat requests populated the controls;
the reviewer first retained neither model because of the residual-duration
pattern, then added duration and retained the extended model with a caveat.

The extended model improved the summed leave-one-out log predictive score by
96.19522 (paired standard error 1.955709). Median noise SD fell from approximately
15.21 to 1.65. The original baseline posterior, scores, common priors and outcome
IDs were identical in the second comparison. This is synthetic acceptance
evidence, not evidence of a scientific discovery.

The extended model's largest-residual check remained `simulation_uncertain`:
its simulated tail fraction was 97.6%, with a Monte Carlo interval of roughly
96.4–98.5%. The retained reason explicitly preserves that unresolved check;
better predictive scores do not establish overall adequacy or causal truth.

The downloaded [browser record](regression/browser-saved.json) contains both
reviews and chat provenance. [Save verification](regression/save-verification.log)
reconstructs each pre-retention scientific basis and verifies preserved history.
The installed CLI successfully inspected this same record in
[text](regression/cli-inspection.txt) and [JSON](regression/cli-inspection.json).
Reopening also restored the reviewed predictors and prior settings without
automatically fitting or accepting them.

## Verification

- Final full R CMD check: **0 errors, 0 warnings, 0 notes**;
  [log](regression-final-check.log).
- Tests cover independent marginal-likelihood references for every LOO score,
  joint posterior simulation moments, data guards, stale and unreviewed results,
  CSV identity and units, native and portable restoration, drafting and human
  retention, and all plot views.
- Jarl passes for the regression implementation and regression tests. A broader
  repository scan reports existing style findings; the development verification
  script also has intentional internal-function access and two leading-zero
  style findings. The repository-wide lint gate is not claimed clean.
- pkgdown builds successfully. Its separate published-URL metadata check cannot
  pass until a site URL is configured; [build log](regression-pkgdown.log).
- The main local app was refreshed on port 3899, preserving its conversation
  store, and returned HTTP 200.

## Scope

This implementation supports 6–500 complete, independent measurements and one
or two numeric predictors with common unknown normal noise. It does not yet
support hierarchical models, interactions, arbitrary formulas or external model
adapters. Regression-specific sensitivity and frozen future-test integration
remain separate work. Repeated model search is exploratory; the reported paired
standard error does not account for that search. Range warnings are not a joint
predictor-support guarantee.

The mathematics follows [normal-model conjugacy](https://www2.stat.duke.edu/~sayan/Sta613/2015/read/chapter_9.pdf)
and the [paired LOO comparison convention](https://mc-stan.org/loo/reference/loo_compare.html).
