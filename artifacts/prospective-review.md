# SUP-014: prospective commitments and assessments

Completed 2026-09-08. Open the main app at http://127.0.0.1:3899 and use `/test`
or **Record → A future test**. The synthetic acceptance record is served at
http://127.0.0.1:3901.

## Delivered behavior

- Preview and freeze the exact claim revision, prior or retained update, available
  evidence references, planned IDs, source, protocol, design, collection deadline,
  interval and complete-cohort assessment rule. Confirmation uses its actual time.
- Attach outcomes and preview/retain an assessment against the original commitment,
  including after later claim revisions. Planned IDs determine the cohort; extra
  rows cannot silently change it. CSV templates and import preparation carry the
  committed metadata into the measurement workflow.
- Preserve waiting, inconclusive and completed results. Missing outcomes wait before
  the deadline and become inconclusive afterward. No imputation or partial numeric
  comparison. Exposure, time, protocol, conversion and repeated-unit issues prevent
  a numerical verdict.
- Retain plan revisions and assessment history, plots, exact references and JSON
  export. Pending previews clear on conversation changes; confirmation checks stale
  inputs, changed records and deadline crossings.
- Public APIs: `commit_test()`, `assess_test()`, `plot_test()`. CLI JSON and human
  inspection include commitments and assessments. Records before schema 7 remain
  readable.

## Verification

- Full test suite: 630 passing expectations before the additional four
  conversation-switch assertions. Final full R CMD check includes those assertions:
  **0 errors, 0 warnings, 0 notes** (`prospective-final-check.log`).
- Final focused lifecycle/UI/plot tests: `prospective-final-focused.log`.
- Air formatting passes. Focused Jarl checks pass. Repository-wide Jarl still
  reports 102 existing style findings outside the new prospective files; no broad
  style rewrite was made (`prospective-jarl.log`).
- pkgdown reference site builds successfully (`prospective-pkgdown.log`).
- Isolated `ir tool install` succeeds; installed CLI inspection reads the synthetic
  assessed-and-revised schema-7 record (`prospective-cli-install.log`,
  `prospective/cli-inspection.json`).
- `Rscript dev/prospective-acceptance.R` creates synthetic complete, revised and
  missing-at-deadline records and an editable plot. The test clock is explicitly
  simulated; these invented outcomes are not prospective scientific evidence.
- Browser acceptance previews and retains the synthetic comparison (difference
  8 MPa, original central 90% interval 1.4923–14.5077 MPa), then previews and freezes
  a new plan at the actual confirmation time with a September 15 deadline.
  Downloaded `prospective/browser-saved.json` validates with two commitments and
  one assessment. Restarting the app from that saved bundle restores both
  commitments and the assessment; the plot and history were visually inspected.

## Limits

The first method assumes independent normal measurements and fixed known positive
measurement SDs. It predicts a difference between two planned sample means.
Intervention and observational designs retain their stated limitations; a matching
interval does not establish claim truth, model adequacy or causality. Exposure and
protocol declarations remain human attestations. SUP-015 sensitivity analysis is
still the next separate slice.
