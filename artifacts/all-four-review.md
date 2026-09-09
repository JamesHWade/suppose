# Persistent R, analysis provenance, belief updates, and real-data acceptance

Completed 2026-09-08 in the local Suppose workspace. The ordinary workbench is
running at http://127.0.0.1:3899/. The saved acceptance example is at
http://127.0.0.1:3900/?shinychat_conversation_id=c_001a0827a5b260a4fe04f41.

## Delivered

- Deputy owns each open conversation's persistent R process. Follow-ups reuse
  variables; reopening, switching or agent reconfiguration creates a fresh owner.
  The host closes disposed owners and retains native static plots and console output.
- Portable schema 6 adds sealed analyses with code, ordered output/PNG segments,
  outcome, runtime identity/generation, source request, model and scientific input
  references. The journal survives context compaction independently of model turns.
  Adding a journal entry does not invalidate an otherwise current proposal;
  scientific record changes still do. Saved code is never executed on import.
- SUP-013 has a bounded analytic Gaussian update with explicitly independent
  measurement units and positive known SDs. The Record drawer previews and retains
  the update beside its original prior. Prior/posterior and future-measurement
  summaries remain distinct. Computation errors, prior-predictive conflict,
  measurement-variation mismatch and insufficient diagnostics are distinguished.
- A retrospective PlantGrowth example exercises public R APIs, the real model,
  native plots, R variable persistence, UI update review, automatic history,
  JSON reopening and the installed CLI.

## Verified evidence

- `all-four-tests-final.log`: 515 passing expectations, no failures/warnings/skips.
- `all-four-release-gates.log`: pkgdown build and final R CMD check;
  0 errors, 0 warnings, 0 notes.
- Air formatting passes. `all-four-new-code-jarl.log`: new integration/update
  modules pass. A broad Jarl scan also reports existing style findings elsewhere;
  this work does not claim the entire pre-existing package is Jarl-clean.
- `plantgrowth/history-verification.log`: three saved analyses, one retained
  update and two original prior revisions. Reopening changed R session identity;
  the following two calls shared identity. The fresh call printed FALSE for
  `exists('pg')`; the next reused `pg` and printed 0.494 without recreating it.
- `plantgrowth/browser-record.json`: portable scientific record from the actual
  saved browser session. `plantgrowth/installed-cli.json` and
  `plantgrowth/installed-cli-verification.log`: the isolated ir-installed CLI
  reads all three analyses and the update, with empty stderr.
- `dev/plantgrowth-acceptance.R`: independently verifies posterior parameters
  against a precision-based closed form; saves prior/update/interval plots and
  preserves original revisions. `dev/verify-plantgrowth-history.R` verifies the
  actual conversation's saved runtime evidence and exports the portable bundle.

The live model initially exposed a Deputy transport defect: wrapped PNG base64
was accepted by the browser but rejected by Meta. Deputy PR 145 fixed the encoder
in d9a88f76e08a31301dd30788e446c1672f009c7b, now pinned in DESCRIPTION and installed
in `.suppose/runtime-library`. Fresh Meta Muse/OpenRouter acceptance passed with
that commit: the model received the native plot and explained its measured data.
Suppose also adapts the upstream S7 permissions, settings, usage and result APIs.

## Scientific interpretation and limits

Data source: R's documented [PlantGrowth dataset](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/PlantGrowth.html),
with 10 ctrl and 10 trt2 observations selected from 30 rows. Source measurement
times and physical weight units are not documented; the example uses `unknown`
and `weight units`. Row IDs are derived from original dataset row numbers.

The demonstration uses analyst-selected central 90% prior intervals [4,6] for
both means, independent prior uncertainty and fixed measurement SD 0.6 in each
group. These are illustrative assumptions, not the user's elicited beliefs or
estimates fitted from the measurements. Exposure is explicitly retrospective.

Observed mean difference: 0.494 weight units. Conditional posterior mean
difference: about 0.45, central 90% interval 0.03 to 0.87. Probability above 0.5
changes from 28.0% to 42.3%. The diagnostic checks are not flagged; that neither
proves model adequacy nor establishes causality or prospective validation.

Paired/clustered likelihoods, inferred measurement SDs and general inference
engines remain unsupported. Arbitrary interactive widgets and rich HTML tables
are not supported by the persistent runtime yet. Context references identify
available inputs and assumptions; reviewing generated code remains necessary.
No Git repository/remote exists for Suppose, so these changes are local and no
Suppose PR or deployment was created.
