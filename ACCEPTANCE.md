# First working version — September 7, 2026

The current P0 verification is recorded in [artifacts/p0-review.md](artifacts/p0-review.md),
including fresh browser save/upload, keyboard and narrow-screen checks, and
cancellation/retry recovery. The sections below retain earlier checkpoint evidence;
the intended-scientist walkthrough remains open.

The current app is a conversation-first inquiry workbench backed by a Deputy
Agent; numerical methods and the temperature example are optional. See the
latest verification section at the end.

This is a working local prototype of **Inspect a belief**, not completion of all
M1 acceptance criteria. The scientific method is intentionally bounded to two
conditions with jointly normal uncertain means and known normal batch variation.

## First-session scenario

All values are invented. A scientist begins with “Higher cure temperature makes
the material stronger.” The retained target is the population mean batch strength
at 160°C minus that at 140°C, for formulation F under protocol P at fixed cure
duration. The material threshold is greater than 5 MPa. A causal interpretation
needs a justified intervention protocol; two conditions do not show monotonicity.

The elicited central 90% intervals for mean strength are 45–55 MPa at 140°C and
51–65 MPa at 160°C. Batch measurement SD is assumed known at 3 MPa for each
condition. The scientist first inspects independent mean uncertainty, then
considers correlation 0.8 to represent shared uncertainty. Original wording,
answers, attribution, assumptions, information basis, candidate identities,
results, seeds, and review history are retained.

| Observable outcome | Evidence |
|---|---|
| Recognizable target with original wording | Claim records, workbench, `suppose_example()` |
| A consequential assumption | Correlation 0 versus 0.8 leaves marginal fit unchanged but moves P(mean improvement > 5 MPa) from 0.717 to 0.878 |
| Concrete challenge | Independently prepared batches under randomized temperatures; specify protocol and assessment before outcomes |
| Ambiguous plausible range | Stored unresolved; never silently interpreted as a probability interval |
| Qualitative-only belief | Retained as a draft judgment without a candidate |
| Contradictory quantiles | Original answer retained; fitting reports a clarification request |
| Unsupported causal interpretation | Remains unresolved; no causal estimator or claim-validation score exists |
| Correction and review | New revision; changing the form after inspection blocks acceptance |
| Reopen | Stored results survive JSON round trip and a new app process; no recomputation |

## Numerical evidence

`Rscript dev/numerical-probe.R` reports independent reference checks in
`artifacts/numerical-probe.txt`. Quantile fitting recovers synthetic N(50, 3²)
and N(58, 4²) means with maximum quantile error below 1.5e-14 MPa. The analytic
contrast SD is 5 MPa and P(delta > 5) is 0.7257469. For 100,000 seeded draws,
the observed mean error is 0.00642 MPa and simulated SD is 5.02002 MPa.

The probe also fits normal and lognormal marginal families to the same two
quantiles: they agree at the elicited endpoints while differing at the median
and in the upper tail. Normal quantile least squares is the implemented method:
it is transparent, deterministic, and analytically checkable. Lognormal support
is an examined alternative, not a shipped second fitting method. Normal
negative-mass diagnostics and the unelicited correlation remain explicit.

## Verification performed

Initial prototype checks: **88 passing expectations; no failures, warnings, or skips**.
`R CMD check --no-manual`: **0 errors, 0 warnings, 0 notes** on R 4.6.1/macOS.
The retained output is `artifacts/check-and-tests.log`.

- Automated tests cover analytic references, simulation, RNG restoration,
  malformed inputs, type and reference integrity, acceptance, immutable earlier
  entries, ambiguous judgment retention, JSON reopen, failed writes, and CLI/R
  agreement. Shiny server tests cover invalid-input recovery, stale acceptance,
  download content, valid and invalid uploads, and assistant proposals that
  cannot mutate accepted records.
- Browser walkthrough: rendered plots and exact numeric summaries; rejected
  reversed quantiles; corrected an interval; created a fourth candidate; accepted
  it with rationale and challenge. The browser displayed 10 MPa expected mean
  improvement and 92.1% conditional prior probability for that corrected example.
- Reopened the persisted `artifacts/tutorial-record.json` in a fresh R/Shiny
  process. The browser displayed its accepted third revision and original 87.8%
  result. This is an illustrative acceptance by “Demo scientist”.
- Browser download event completed. The in-app browser file chooser did not open
  under automation, so visible upload interaction remains unverified; upload and
  download handlers are covered by Shiny server tests.
- Keyboard Tab navigation visibly focused the labeled name field. The layout
  was inspected at 390px width: cards stack vertically, the plot uses a compact
  legend, and wide tables have focusable horizontal scrolling. This is a focused
  accessibility check, not a full assistive-technology audit.
- The official ir 0.4.0 `rx` resolved and launched the package with only its core
  dependencies. `ir tool install` installed a launcher in a temporary tool store.
  The installed launcher handled paths containing spaces, emitted valid JSON on
  stdout with empty stderr on success, and rejected missing seeds with nonzero
  exit and empty stdout. Its draws and analytic results matched R exactly.
- Air formatting and generated roxygen help are in place. The pkgdown site builds
  with complete reference metadata. `pkgdown::check_pkgdown()` reports the absent
  canonical URL because no documentation site or repository remote is configured.

## Remaining validation and scope

The workbench uses the tested shinychat development revision recorded in
DESCRIPTION. That source revision could not be retrieved from its recorded
public repository during verification, so it is not declared as an installable
remote. The UI runs against the existing local installation; a fresh portable UI
installation remains unverified. No domain-user acceptance interview has occurred.

The UI edits the fixed 140/160°C MPa example; R APIs can use two other ordered
conditions and consistent units. Uninspected form edits are not saved; sessions
require an explicit download before closing. A retained claim draft does not
capture all uninspected form fields. Normal tails, known noise, marginal
elicitation mismatch, and limited dependence alternatives remain method limits.

Observation updates, prospective test commitments, sensitivity analysis beyond
changing these supplied assumptions, model expansion, shared knowledge adapters,
and broader decision workflows remain backlog items. No external publication,
CI remote, multi-user deployment, or package release was created.

## Conversational elicitation increment — September 7, 2026

`dev/assistant-probe.R` records a deterministic vague range → probability
clarification → independence assumption → correlation correction → explicit
acceptance walkthrough. It writes `artifacts/assistant-record.json` and
`artifacts/assistant-probe.txt`. A separate R process reopened the bundle and
verified the acceptance link and all six conversation messages. This is a
scripted fixture, not a claim about live model performance.

The assistant exposes five bounded tools: read formalization, propose claim,
propose judgment, propose assumptions, and preview. Source quotes must occur in
user messages; numerical parameters must occur in those quotes. Probability-free
ranges remain unfitted. Previews call the package's numerical APIs, and a
completed proposal retains the exact preview identity, conversation, model and
tool receipts. Human application and acceptance are separate actions. Schema-2
bundles add this provenance; schema-1 bundles remain readable.

The browser exercised actual ellmer/shinychat streaming against the local
completion-protocol fixture in `dev/fixture-server.py`: tool call → completed
proposal → apply as revision 4 → inspect as revision 5 → explicit acceptance.
The browser showed the retained fixture transcript and acceptance rationale.
A failed HTTP response also returned to a usable chat input with no applied
proposal. Cancellation, late tool calls, stale records, changed forms, repeated
application, clarification, and corrections have deterministic regression tests;
real-provider interruption/retry stress testing remains open.

Validation for the earlier elicitation increment: **112 passing expectations**, and
`R CMD check --no-manual`: **0 errors, 0 warnings, 0 notes**.
Air formatting, generated help and pkgdown build completed. No canonical
site URL is configured.

`suppose_muse()` configures `meta/muse-spark-1.3-contributor` through OpenRouter.
**Live Muse inference is not yet verified:** `OPENROUTER_API_KEY` was unavailable
in a fresh R process. After local credential configuration, the opt-in
`Rscript dev/live-assistant.R` performs a synthetic live walkthrough and bundle
round trip. Contributor training use is disclosed. No credentials are stored in
records, but applied assistant proposals retain their conversation.

## Chat-first inquiry and Deputy integration — September 7, 2026

The default `suppose_app()` now opens an empty conversation and a developing
record. Team decisions, service ideas, research questions and other domains use
their own wording, targets, scope, horizon, expectations, assumptions and open
questions. The old temperature form is available as `suppose_example_app()`;
loading its worked record is an explicit choice.

`suppose_agent()` returns a Deputy Agent subclass passed directly to
`shinychat::chat_server()`. It adds only dynamic argument collection required by
shinychat's spliced input; the superclass still executes the governed stream.
The installed Deputy method otherwise raises `invalid argument type` on that
input. A regression test checks forwarding of messages, stream mode, cancellation
controller and run context. No execution loop is duplicated in Suppose.

The Agent has four inquiry tools and bounded per-response usage. They can read,
propose and preview; they cannot apply or accept a revision or invoke general
file, shell, web or R execution. Proposal staging is a product transaction around
a Deputy run, with stale/cancelled-request guards. Stopped runs cannot publish
completed proposals. The per-session Agent and proposal state are not shared
between users.

Verification performed:

- **189 passing expectations**. `R CMD check --no-manual`: **0 errors,
  0 warnings, 0 notes**. Output: `artifacts/inquiry-check.log`.
- Cross-domain fixtures preserve interpretations without invented units or a
  forced numerical model. A changed problem cannot inherit the old model.
- The optional normal method was tested with response in mV at 2 and 4 seconds,
  establishing that its numerical conditions and units are supplied by the domain.
- The real Deputy Agent completed two tool-using calls against a local scripted
  HTTP model fixture. A team-cycle-time correction was applied and semantically
  accepted without a numerical model. `artifacts/inquiry-record.json` retains
  four messages and two Deputy run receipts, including run identity, completion
  status and provider-reported usage. A fresh R process reopened it successfully.
  These are synthetic inputs and token reports, not live model evaluation.
- The browser exercised the actual shinychat → Deputy → ellmer stream: team
  question, proposed interpretation, conversational correction of the horizon
  and assumptions, application, and explicit acceptance of meaning. Cancelling
  a later response discarded the incomplete proposal; retrying then declining
  left the accepted interpretation unchanged.
- Shiny server tests cover an initially empty local chat, manual interpretation,
  semantic review, unsaved-editor rejection, download and reopen with messages.
- `dev/inquiry-fixture-server.py`, `dev/run-inquiry-fixture.R` and
  `dev/inquiry-probe.R` reproduce the scripted integration. The fixture is test
  infrastructure and is never substituted for a model in the product.

**Live Muse inference verified with synthetic inputs** after the account owner
completed OpenRouter's age confirmation and training-use preference. The live
`Rscript dev/live-inquiry.R` walkthrough completed two Deputy-governed turns:
clarifying a team-delivery question, then proposing a non-numerical interpretation
with scope, time horizon, units, assumptions and open questions. The harness
explicitly applied and semantically accepted the proposal, saved the conversation
and record, and verified an identical JSON round trip. This confirms the live
integration, not the correctness of the synthetic belief.

Domain-user acceptance, other analytical methods,
external evidence retrieval and portable installation of the development UI
stack remain open. Semantic acceptance records agreement about meaning; it does
not certify the belief or approve any attached model's numerical conclusions.

### Welcome and record drawer follow-up

- The empty conversation now displays an introductory welcome and three editable
  starting prompts. The composer and footer remain at the bottom of the viewport.
- The native shinychat drawer starts closed. The footer Record control opens it;
  completed proposals change its label to `Record · suggestion ready`.
- Browser verification covered prompt insertion, opening and closing the drawer,
  model disclosure, and a scripted Deputy response whose proposal was reviewed
  and applied inside the drawer. This was a local fixture, not live Muse output.
- All 189 expectations pass. R CMD check reports 0 errors, 0 warnings, 0 notes
  (`artifacts/drawer-check.log`; remote clock verification disabled).
- A separate browser session also completed a live Muse response through
  shinychat and Deputy. It called `propose_interpretation`, rendered the reply,
  and changed the footer to `Record · suggestion ready`.

### Slash commands and model picker

- Native shinychat command discovery exposes `/record`, `/model`, `/help`,
  `/clarify`, `/assumptions`, `/challenge`, and `/predict`. Thinking commands
  preserve supplied arguments and draft an editable prompt without inference.
- The asynchronous, account-filtered OpenRouter catalog supports model search,
  provider and token-price filters, pricing/context details, output-token limits,
  and refresh. Only text/tool-capable, non-batch model entries are included.
  The live catalog contained 293 qualifying entries during verification.
- Browser verification switched a live conversation from Muse Contributor to
  GPT-4o mini. The new model proposed an interpretation using the earlier words
  and recalled the inquiry code name given to Muse. The prior chat remained
  visible, and the new proposal was available in the record drawer.
- Server tests verify explicit switching, preserved record/transcript, blocked
  switching during a response, pending-proposal preservation, attribution of
  subsequent corrections, command-argument retention, invalid selection, and
  continued local-guide operation after a catalog failure.
- `artifacts/controls-check.log`: R CMD check reports 0 errors, 0 warnings,
  0 notes. Browser checks also covered native command discovery, a command with
  arguments, provider filtering, and the scrollable picker with fixed actions.
- The updated app runs at http://127.0.0.1:3895/ so the user's active conversation
  and pending interpretation at port 3891 remain available.

### Simplified controls

- Supersedes the thinking-command controls above: the native slash palette and
  help now expose only `/record`, `/model`, and `/help`. Inquiry prompts are no
  longer encoded as command templates.
- The model picker initially shows search, current model, and compact token
  pricing. Provider/price filters, output limits, context details, and refresh
  live inside collapsed Advanced options.
- Focused inquiry tests pass (`artifacts/simple-controls-tests.log`).

### Live conversational quality walkthrough

See [WALKTHROUGH.md](WALKTHROUGH.md) for five live Muse responses across meeting
and migration-service examples. Scope correction and practical suggestions
worked, but a conditional interview scenario became a stated expectation in
the proposed record. The walkthrough also found repeated taxonomy, a request
to define what the person had said they could not define, irrelevant numerical
method details, and literal `null` units. Both proposals remain unapplied.
This adds live quality evidence; it does not close domain-user acceptance.

### First-session quality increment

[QUALITY-REVIEW.md](dev/notes/QUALITY-REVIEW.md) records the fixes, adversarial findings,
failed first live pass, successful replay, and remaining limits. The increment
adds source-preserving expectations, separate assistant ideas, direct reviewer
correction with retained provenance, guarded acceptance, stable pending proposals,
and qualitative CLI inspection. Live browser cancellation/retry/decline and
keyboard correction/acceptance were checked in separate fictional sessions.

The complete local suite passes 307 expectations in 52 tests without skips.
R CMD check reports 0 errors, 0 warnings, and 0 notes. A fresh isolated ir/rx
installation verifies the current CLI, including numerical equivalence, saved
qualitative meaning, and clean error/output behavior. The updated app runs on
port 3896; earlier user sessions were preserved. Intended-user acceptance remains
open.


### Observation import increment

[OBSERVATIONS-REVIEW.md](dev/notes/OBSERVATIONS-REVIEW.md) records SUP-012 implementation,
critical review, and validation. The actual browser upload/preview/attachment and
download path retained a synthetic three-row CSV with missingness and repeated
measurement flags; duplicate import was refused. A fresh R process reopened the
browser download with evidence and conversation intact. The 390-pixel layout was
inspected. The public Shinychat source now builds, and a clean isolated ir library
completed CLI, UI-constructor, and live Deputy/Muse checks on macOS. This
supersedes the earlier unretrievable-source installation limitation.

362 expectations pass; R CMD check reports 0 errors, warnings, or notes. A small
source-matching repair occurred during the live response, and a non-temporal
phrase was still assigned as a horizon; model output still needs human review.
There is no posterior or prospective assessment yet. Full screen-reader and
intended-user acceptance remain open.
