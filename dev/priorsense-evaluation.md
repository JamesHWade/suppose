# Priorsense adapter evaluation for SUP-015

Evaluated 2026-09-08 before selecting the implementation. The development script
`dev/priorsense-evaluation.R` uses priorsense **1.2.0** installed in an isolated
library. It supplies 40,000 reproducible draws from Suppose's two-mean normal
posterior, their full joint log prior and full log likelihood, and the target
mean difference to `create_priorsense_data()` and `powerscale()`.

The [current data adapter API](https://n-kall.github.io/priorsense/reference/create-priorsense-data.html)
accepts posterior draws and evaluated log densities. The
[power-scaling API](https://n-kall.github.io/priorsense/reference/powerscale-overview.html)
returns weighted draws and diagnostics. The tested call uses one component at a
time, powers 0.8, 1 and 1.25, no resampling and no moment matching. At power 1
there is no `.log_weight` column, so the adapter uses equal weights.

All six weighted estimates agree with a separate precision-matrix calculation
within 0.016 MPa (predeclared tolerance 0.025 MPa). The observed nonbaseline Pareto-k
values range from -0.981 to 0.213. Negative estimates are valid diagnostic outputs;
no failures are hidden or clamped. See `artifacts/priorsense-evaluation.log`,
`artifacts/priorsense-adapter-comparison.csv` and the captured adapter attributes.
These results verify this adapter example, not every model or scaling range.

## Decision

Use exact analytic Gaussian conditioning for the currently supported normal
model. A powered joint normal prior has covariance Sigma/alpha. Powering the full
likelihood multiplies its precision contribution by alpha. The existing Joseph
conditioning form supports singular priors without inverting their covariance;
an independent precision implementation tests the nonsingular case. No sampled
approximation, importance-weight diagnostic or runtime priorsense dependency is
needed for these calculations.

Keep the evaluated priorsense adapter as a development reference for future
sample-based models. Such an adapter would need draw-quality and importance-weight
diagnostics, explicit failed/unreliable results and appropriate moment-matching
support before becoming a workbench method. We do not label the analytic grid
with priorsense's CJS sensitivity scores or thresholds.

## Scientific scope

The first method changes full joint prior strength or likelihood weight separately.
It preserves means, correlation, support, observed data, and fixed physical
measurement SDs. Likelihood weighting does not invent additional independent
observations. Predictions retain the original future-measurement noise; only
posterior uncertainty changes. This does not explore alternate prior shapes,
likelihood families, dependence structures or global robustness. Review thresholds
are selected in target units and probability points by the user.

A comparison with a retained prospective assessment is an exploratory alternative
interval evaluated after outcomes, not a revised preregistration or fresh test.
It requires the same retained update basis; waiting/inconclusive assessments have
no numerical comparison. Original commitments and assessments remain intact.
