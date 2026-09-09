# Continue, test, and challenge a research plan

September 9, 2026. Implements SUP-037, SUP-030 and SUP-036 in the existing
one/two-predictor normal/inverse-gamma regression family.

## Delivered behavior

- A reviewed research plan can seed a new draft with its exact candidates,
  contrast, costs, budget and utility preference. A new review links to its
  source plan. Populated forms and concurrent edits require an explicit choice
  before replacement; changed claim revisions cannot reuse a stale model.
- Regression tests freeze exact future IDs/settings, model and claim references,
  source/protocol, assignment description, deadline and assessment rule. The
  supported rules are one joint Student-t outcome region or a future sample-mean
  difference interval with unknown noise. Both require the complete cohort.
- Future evidence is versioned. Corrections name one active attachment and retain
  exactly its original IDs; earlier attachments and assessments remain intact.
  Assessments check settings, units, protocol, independent-unit identities,
  exposure declarations and chronology against the frozen prediction.
- Regression sensitivity powers the full joint prior in coefficients and variance
  or the full Gaussian likelihood, one component at a time. Each conjugate
  posterior is solved exactly. Comparisons retain contrast and noise summaries,
  predictive checks, optional candidate benefits/ties, and changed recommendations.
  Utility thresholds vary preferences only under the original posterior.
- Chat stages reviewable forms. Human actions freeze tests, attach measurements,
  retain assessments, and retain sensitivity reviews. Schema 13 records and native
  history preserve their provenance. CLI inspection includes the new results.

## Independent numerical checks

`tests/testthat/test-regression-prospective.R` draws 20,000 posterior coefficient,
variance and future-outcome realizations directly. The observed joint-region and
sample-mean-contrast coverages are within one percentage point of 90%; their
covariance matches the analytic joint prediction. The future sample-mean scale
exceeds its population-mean counterpart.

`tests/testthat/test-regression-sensitivity.R` compares differences of independent
joint log-density evaluations with the completed-square posterior kernels, and
checks power one against the original fit. Improper joint-prior powers are rejected.
A six-observation synthetic example with fixed costs 0 and 4.3 changes the preferred
experiment from low to high under prior power 0.8. An informative 120-observation
case keeps its recommendation under all five reference/prior/likelihood variants.
An orthogonal design checks signed-zero covariance serialization.

## Browser acceptance

The fictional coating record from the earlier BED walkthrough was reopened in a
local app with an isolated history directory. `dev/verify-research-loop.cjs`:

1. Resumed the retained plan, protected a populated form, and used the live agent
   to change only T50x6 cost to 0.1. The second human review chose T70x6, preserving
   the original review and other settings. The explicit field-preservation request
   leaves the original zero-cost rationale verbatim; chat flags that wording as
   stale. In ordinary work, the reviewer should update that explanation too.
2. Retained separate prior/likelihood and utility sensitivity variants.
3. Froze six new fictional batches, three per temperature at fixed drying time,
   before generating their outcomes. The assessment rule was sample mean B minus A.
4. Attached half the cohort (awaiting outcomes), then completed it (within the
   prediction), and corrected one measurement (outside the prediction). The
   original frozen prediction and earlier assessments remained identical.
5. Checked mobile layout, review controls and browser errors.

`dev/verify-research-loop-history.cjs` opened the saved native conversation URL and
compared both plans, the commitment, three evidence versions, three assessments
and the sensitivity review exactly with the downloaded record. It also checked
retained comparison layouts at desktop and phone widths.
`dev/verify-research-loop-records.R` independently validates those browser-created
and reopened records in R, including preservation of original observations,
regressions, revisions, R analyses and the first planning review.

The full local acceptance scripts use generated coating artifacts from the prior
walkthrough, which are intentionally not committed. The unit tests and evaluated
`vignettes/research-loop.Rmd` supply self-contained synthetic examples.

## Persistence and presentation fixes found during verification

- JSON readers normalize signed zero in covariance matrices. New matrix payloads
  normalize zero before sealing; nonzero entries and numerical meaning are unchanged.
- Assessment reconstruction permits final-bit numeric round-trip differences,
  while requiring exact categorical status, issues and evidence references.
- Automatic history uses shinychat's supported new-conversation operation when
  opening a portable record. Rebinding the chat client freezes transient history
  actions so the last new/select/edit command is not replayed.
- Comparison tables scroll inside the Record drawer, plot images resize within
  it, and long native mathematical displays do not widen phone-sized guide pages.

## Verification

- Full package tests: 1,476 assertions passed, no warnings or skips.
- Focused final form/history tests: 78 assertions passed.
- Air formatting and focused Jarl checks passed; the broad Jarl scan retains
  existing warnings in unchanged files.
- Nine executable guides and the reference site built successfully. The strict
  pkgdown metadata/index check passed with an in-memory local URL; the private
  repository intentionally does not declare a public documentation URL.
- R CMD check: zero errors, warnings or notes; all 1,476 assertions pass.
- Rendered documentation: 12 pages checked at desktop/mobile widths, 144 local
  links and anchors valid, loaded figures with alt text, working navigation,
  keyboard search and skip link, and no browser JavaScript errors.
- Detailed logs are local `artifacts/research-loop-check-final.log` and
  `artifacts/research-loop-docs-browser.log`.

## Limits

These are conditional predictive checks and bounded sensitivity comparisons,
not causal certification or a general robustness guarantee. Collection/exposure
metadata are attributed declarations. No experiment is executed, no alloptr
campaign is dispatched, and no interaction/nonlinear model is introduced.
The intended-user validation in SUP-011 remains separate.
