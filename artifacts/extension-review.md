# SUP-016: model growth and chat-filled forms

Completed 2026-09-08. Main app: http://127.0.0.1:3899.
Synthetic acceptance app: http://127.0.0.1:3903.

## Delivered

- Compare the original two-anchor normal prior with one added shared normal
  coefficient, independent of the anchor means. Compare the same scenarios under
  raw-unit and meaningful-change scaling. Show both mean and outcome uncertainty,
  optional probabilities outside plausible bounds, and the matched contrast.
- Label straight-line interpolation/extrapolation and the measurement-variance
  projection as new comparison assumptions. The old judgments did not imply them.
- Retain a reviewed alternative with its scientific reason, selected scaling,
  assumptions, predictions, exact original references and optional chat draft.
  Schema 9 reads older records; existing priors, updates and tests remain intact.
- Real `draft_model_extension` and `draft_sensitivity` tools populate the actual
  controls, open the relevant panel and prepare a preview after chat completes.
  Omitted values preserve current settings or use labeled defaults. Routine
  controls are collapsed; review and retain remain explicit human actions.
- Protect edits made while the agent works. Restored pending drafts prepare their
  previews directly. Cancelled or stale responses do not publish form changes.
  Saved reviewed results retain the source request and original suggested values.

## Verification

- Final R CMD check: **0 errors, 0 warnings, 0 notes**, including the complete
  suite (`extension-final-check.log`). Focused browser-regression tests also pass
  (`extension-final-focused.log`, `extension-restoration-tests.log`).
- Independent reference calculations cover each aligned scenario, unit invariance,
  predictive inflation, centering, shared-effect cancellation, singular/zero
  uncertainty, extrapolation labels, invalid inputs, overflow, stale proposals,
  unchanged original history and JSON restoration.
- Live Muse chat called `draft_model_extension`, filled duration in minutes with
  reference 60 and meaningful change 10, and prepared the preview. A second real
  request changed SD to 2 and plausible bounds to 0–100 while preserving the
  reference and scale. The actual controls matched those values.
- The revised example's widest central 90% outcome intervals were approximately
  18.4 MPa (reference), 68.3 MPa (raw-unit reuse), and 19.6 MPa (scaled).
  Raw-unit reuse placed up to 2.9% outside the selected plausible bounds.
- Native history contained the pending draft with zero retained extensions.
  After server restart/reopen, the preview restored directly. Human retention
  saved the reviewed extension. This uncovered and fixed a restore/conflict bug.
- A third live request called `draft_sensitivity`, selected prior strength only,
  and populated powers 0.8/1/1.25 and thresholds 1 MPa/5 percentage points. Its
  preview restored on restart and retained successfully. A browser integer versus
  double comparison bug was fixed and covered by a regression test.
- Downloaded `extension/browser-saved.json` validates with one extension and one
  sensitivity, their source requests and chat provenance, and identical original
  revisions and updates. Reproduce with `Rscript dev/verify-extension-history.R`.
- Isolated `ir tool install` and installed CLI JSON/human inspection succeed
  (`extension-cli-install.log`, `extension/cli-inspection.json` and `.txt`).
- Air formatting and focused Jarl checks pass. The pkgdown reference site builds
  (`extension-pkgdown-build.log`). `check_pkgdown()`'s publication metadata check
  remains unavailable because this local project has no configured published URL;
  no deployment URL was invented. All new exports are in the reference index.
- The static comparison plot was rendered and visually inspected. Main app 3899
  was refreshed after verification; native conversation storage was preserved.

## Limits

This implements one additive predictor, not interactions, arbitrary simulators,
extended posterior fitting or automatic prior calibration. Existing update and
test methods do not switch to the retained alternative. Default coefficient spread
is a starting suggestion, not an elicited belief. Plausible bounds are optional;
they are never inferred automatically. Predictive consistency is not empirical
validation, causal identification or mechanistic equivalence.

Pending chat forms persist in native history; portable record downloads include
their provenance after retention. Manual unretained form edits are not a portable
scientific record. The live examples use invented data and explicitly synthetic
requests. Chat prose remains model-generated; the controls and saved records are
the inspectable source of the executed comparison.

Run `Rscript dev/extension-acceptance.R` for the controlled scaling example.
