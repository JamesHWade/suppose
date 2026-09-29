# Close one Bayesian model-revision loop

Authorized 2026-09-08: take a substantial implementation chunk covering regression
with unknown noise, predictive checks, an added predictor, fitted comparison and
reviewed retention. Continue the actual chat form tools and low-burden defaults.

## Plan and acceptance

- [x] Attach numeric predictor measurements keyed to existing observation IDs,
  preserving evidence source, units, roles, exposure and revision references.
- [x] Implement a bounded normal regression with a proper normal/inverse-gamma
  prior and unknown common measurement variance. Expose the new assumptions;
  it does not silently convert the old fixed-noise model or reviewed extension.
- [x] Preview priors; fit exactly; show posterior parameter/predictive uncertainty
  and joint posterior predictive checks, with reproducible simulation provenance.
- [x] Add one predictor and compare fits on identical observations using exact
  leave-one-out refits and paired predictive-score differences. Preserve original
  fits and reviewed reasons; permit retaining neither model.
- [x] Provide actual chat form drafting, protected edits, preview/fit/review UI,
  native history restoration and portable records/CLI inspection.
- [x] Verify an end-to-end synthetic omitted-predictor example, reference math,
  safeguards, save/reopen, live chat, package checks and documentation.

## Decisions

Use exact conjugate inference for the first bounded implementation, avoiding
sampler controls. Coefficients conditional on variance are normal, and variance
has a proper inverse-gamma prior. Explain their dependence. Predictor transforms
are fixed and recorded; never center the outcome or tune priors from its realized
values. Posterior predictive simulation uses joint parameter draws. LOO fits use
the same fixed prior in every fold, and compare the same measurement IDs.

This is an iterative predictive comparison after viewing data, not an independent
prospective test or proof of causal/mechanistic truth. Interactions, hierarchical
models, arbitrary formulas, simulators, and automated experimental design remain
outside this increment. No remote repository or publication is requested.

## Sources

- [Normal linear-model conjugacy](https://www2.stat.duke.edu/~sayan/Sta613/2015/read/chapter_9.pdf)
- [Paired LOO model comparison](https://mc-stan.org/loo/reference/loo_compare.html)
- [Bayesian workflow](https://arxiv.org/abs/2011.01808)

## Completion

Completed and verified. See [verification and limits](../../artifacts/regression-review.md).
