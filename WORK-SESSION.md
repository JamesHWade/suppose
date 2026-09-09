# First-session quality work

User authorization: continue a substantial backlog increment, with adversarial
review and critique. Preserve open user conversations. Local development only.

## Selected scope

- SUP-003/004/010: preserve user expectations and assumptions with their source
  context; keep assistant suggestions and hypothetical questions distinct.
- SUP-009: make proposal review and correction usable; fix absent-field display
  and ensure review cannot accidentally accept a different visible state.
- SUP-011: replay the live quality failures, run package checks, retain evidence
  and critique, and leave intended-user validation open.
- SUP-027: expose saved qualitative meaning in CLI inspection and verify the
  current package through isolated ir/rx launchers.

## Gates

1. Inspect the current meaning/proposal boundary and choose a bounded correction.
2. Implement and exercise malformed, conditional, stale, and cancelled cases.
3. Review the delta adversarially and fix reproducible findings.
4. Exercise the new app in separate sessions, including real model responses
   using explicitly fictional examples; preserve existing sessions.
5. Run the package gates and update the backlog with evidence and remaining gaps.

## Progress

- Baseline copied to a temporary review directory before edits.
- Observed starting defects are recorded in WALKTHROUGH.md.
- Design and implementation completed for the selected bounded increment.
- Implemented the selected quality changes and qualitative CLI inspection.
- Adversarial review findings and live replay results are in QUALITY-REVIEW.md.
- Final local suite: 52 tests, 307 passing expectations, no failures or skips.
- R CMD check: 0 errors, 0 warnings, 0 notes. Final CLI and documentation
  verification completed; original user sessions remain untouched.
- Final app left running at http://127.0.0.1:3896/. SUP-027 is implemented;
  intended-user acceptance and full small-screen/accessibility review remain open.

## 2026-09-08: persistent execution and learning from measurements

All four requested increments are implemented. See
[the acceptance report](artifacts/all-four-review.md) for exact evidence and limits.
Deputy is pinned to d9a88f76e08a31301dd30788e446c1672f009c7b in the isolated runtime
library. The completed suite has 515 passing expectations; pkgdown and R CMD check
pass (0/0/0). A real Meta/PlantGrowth conversation verifies native plots, fresh
reopening, persistent follow-ups, saved analysis provenance, and a retained
normal update. The main app runs on 3899; the saved acceptance example runs on 3900.

## 2026-09-08: prospective tests (SUP-014)

Completed: freeze a two-condition future-mean prediction with identified measurement
IDs, source, protocol, deadline and assessment rule; assess all planned outcomes
against that original commitment, preserving missing/inconclusive results and
later revisions. Support an explicitly selected prior or retained update as the
prediction basis. Add reviewable UI, saved records, CLI inspection and lifecycle
verification. Sensitivity analysis remains the next separate backlog item.

SUP-014 verification and limits: [prospective review](artifacts/prospective-review.md).

## 2026-09-08: sensitivity to model assumptions (SUP-015)

Completed prior-strength and likelihood-weight comparisons using the exact normal
method, after evaluating a priorsense 1.2.0 adapter against current APIs. Preserve
original updates and prospective assessments; retain comparison failures and
follow-up questions. Browser save/reopen and follow-up drafting verified; full package check passes
with 0 errors, 0 warnings and 0 notes. See [verification](artifacts/sensitivity-review.md).

## 2026-09-08: model growth and chat-filled forms (SUP-016)

Completed one additive predictor comparison with explicit new assumptions,
meaningful-change scaling and reviewed alternatives alongside original history.
Added real agent tools to populate extension and sensitivity forms with preserved
values and labeled defaults. Live chat, partial updates, pending-draft restoration,
human retention, portable provenance and installed CLI inspection verified.
Fixed two browser-discovered regressions with focused coverage. Final R CMD check
passes with 0 errors, 0 warnings and 0 notes; main app 3899 refreshed.
See [verification and limits](artifacts/extension-review.md).

## 2026-09-08: fitted Bayesian model revision (SUP-028)

Completed unknown-noise regression, posterior predictive checks, one added
predictor, exact leave-one-out comparison and append-only reviewed choices.
Actual chat tools populate the form; native restoration preserves pending drafts
and reviewed settings. Live synthetic acceptance verifies both saved reviews,
unchanged original history and the unresolved Monte Carlo tail check.
Final R CMD check passes with 0 errors, 0 warnings and 0 notes. Main app 3899
refreshed and HTTP 200 verified. See [verification and limits](artifacts/regression-review.md).

## 2026-09-08: realistic chat workflow repair

Repaired R-tool reconfiguration with archived-result preservation, automatic
compact record context, compact validation errors, chat-assisted table import,
and scientific/persistence guidance. Regression priors now expose implied
predictor-range mean changes before fitting. Repeated the fictional coating
conversation through R plot, exact source import, model criticism, adding time,
review retention and native reopening. Both saved models and R results survive.
See [walkthrough evidence](artifacts/chat-walkthrough/review.md) and
[model-guided research recommendations](artifacts/bayesian-research-design.md).
Regression-specific prospective commitments and automated sensitivity remain
unimplemented; the final prompt correction makes this explicit.

Final source: R CMD check passed with 0 errors, 0 warnings and 0 notes.
Main local app refreshed and HTTP 200 verified. Saved-record verification is
reproducible with `python3 artifacts/chat-walkthrough/verify_saved.py`.

## 2026-09-08: exact Bayesian experimental design (SUP-029)

Implemented alloptr's exact normal/inverse-gamma contrast design engine and
Suppose's reviewed-model adapter, chat drafting, human planning review and portable
schema 11 records. Supports estimation or two-protocol linear-utility decisions,
independent replicated settings, explicit feasibility, unit budgets and costs.
Both packages pass R CMD check with 0 errors/warnings/notes; optional alloptr
providers remain skipped when absent. Actual fictional coating chat, pending-draft
restoration, retained choice and native reopening verified with exact score replay.
SUP-030–SUP-036 and expanded SUP-019/SUP-020 define evidence gates for further work.
See [BED verification](artifacts/bed-review.md).
