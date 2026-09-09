# SUP-015: prior and likelihood sensitivity

Completed 2026-09-08. Use `/sensitivity` or **Record → Check sensitivity** in the
main workbench at http://127.0.0.1:3899. The synthetic acceptance app runs on
http://127.0.0.1:3902.

## Delivered

- Select a retained update, prior strength and/or likelihood weight, powers, and
  outputs: mean difference, probability above the claim threshold, and retained
  test assessments. Set review thresholds in outcome units and probability points.
- Preview exact analytic results, central intervals, baseline comparisons, model
  checks and explicitly failed computations. Keep prior and likelihood changes
  separate and their scope visible.
- Retain the analysis, references, settings, failures and follow-up questions in
  a schema-8 record. Old schemas remain readable. Original priors, updates,
  commitments and assessments are preserved. Stale previews cannot be retained.
- Matching prospective assessments can be compared against exploratory alternative
  intervals, with unchanged future measurement noise. Other bases are explicitly
  not comparable; waiting/inconclusive assessments stay nonnumeric.
- Draft an actionable review of the latest retained finding in chat. The draft
  identifies its analysis and update, asks about elicitation or observation-model
  assumptions, and waits for the user to send it.
- Public APIs: `sensitivity_analysis()`, `record_sensitivity()`,
  `plot_sensitivity()`. CLI inspection and assistant inquiry reads include results.

## Implementation choice

A priorsense **1.2.0** adapter was evaluated before the implementation was chosen.
All six estimates for powers 0.8, 1 and 1.25 agreed with an independent precision
calculation within 0.016 MPa. The current bounded normal model uses exact analytic
conditioning; no runtime priorsense dependency or sampled sensitivity score was
introduced. See [adapter evaluation](../dev/priorsense-evaluation.md), its script,
`priorsense-evaluation.log` and `priorsense-adapter-comparison.csv`.

## Verification

- Full R CMD check: **0 errors, 0 warnings, 0 notes**, including the complete test
  suite (`sensitivity-final-check.log`). The suite contains 744 expectations.
- Reference tests cover all prior/likelihood grid points, known sensitive and
  insensitive cases, singular priors, selected quantities, numeric failures,
  original assessment boundaries, unchanged physical prediction noise, missing
  assessments, mismatched bases, stale previews and JSON integrity/references.
- Browser acceptance: previewed and retained a synthetic conflicting-data case.
  Original mean difference is approximately 50 MPa; the selected powers move it
  to approximately 45–55 MPa. The chosen 1 MPa review threshold triggers questions
  about both prior strength and likelihood weight, while original model checks
  remain visible.
- Downloaded `sensitivity/browser-saved.json` validates with one original update
  and one sensitivity entry. A restarted app loaded that saved result. The
  follow-up button populates the main chat input and leaves the message unsent.
- Plots rendered to PNG and were visually inspected. The reference site builds
  (`sensitivity-pkgdown.log`); Air source formatting and focused Jarl checks pass.
- Isolated `ir tool install` succeeds. Installed CLI reads the saved sensitivity
  record in JSON and human-readable form (`sensitivity-cli-install.log`,
  `sensitivity/cli-inspection.json`, `sensitivity/cli-inspection.txt`).

Run `Rscript dev/sensitivity-acceptance.R` to reproduce synthetic sensitive,
insensitive and assessment-boundary examples. Simulated clocks and invented
outcomes demonstrate behavior; they are not prospective scientific evidence.

## Limits

Power scaling changes strength within the existing joint normal prior or weights
its full likelihood. It does not change prior shapes, likelihood families,
independence, correlation or fixed physical measurement SDs. Staying below a
selected review threshold does not establish model adequacy or global robustness.
Assessment comparisons are exploratory alternatives after outcomes, not revised
preregistrations. SUP-016 model-growth review remains a separate backlog item.
