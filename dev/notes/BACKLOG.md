# Suppose backlog

Created September 7, 2026. This is the implementation backlog for the direction in
[CONCEPT.md](../../CONCEPT.md), using the vocabulary in [CONTEXT.md](../../CONTEXT.md).

The first milestone delivers a complete local experience: state a claim, elicit
expectations, inspect implied outcomes, correct the formalization, accept it,
and reopen it. An optional assistant helps the person express meaning; the R
APIs and explicit statistical procedures own numerical results.

## P0 completion checkpoint — September 8, 2026

SUP-003, SUP-004, SUP-007, SUP-009 and SUP-010 now have bounded implementations
and reproducible browser/API evidence. The workbench retains broader expectations,
relates independent claims to retained priors, and inspects explicitly assumed
behavior beyond the elicited anchors. Keyboard and 390px checks, native file
reopening, and cancellation/retry recovery are covered in the
[P0 acceptance report](../../artifacts/p0-review.md).

SUP-011 remains **partial**: an intended scientist or engineer still needs to
recognize the formalization, name an assumption, and propose a challenge. Agent
operated synthetic examples do not satisfy that requirement. Full assistive
technology and cross-platform testing are also outside the current evidence.

## Research-analysis checkpoint — September 8, 2026

SUP-012–SUP-016 and the added SUP-028 now provide a bounded Bayesian analysis and
model-revision loop: attributed measurements, prior/posterior inspection,
prospective checks for the original normal model, sensitivity, prior model-growth
review, and fitted regression comparison with unknown measurement variance.
Actual chat tools prepare review forms. SUP-028 preserves both original and
revised fits, predictive diagnostics and model-choice reasons; see
[regression verification](../../artifacts/regression-review.md).

The realistic coating walkthrough also prompted a unified, chat-prepared table
import, current-record context, compact validation errors and a repaired Deputy
session transfer for tool reconfiguration. Outcomes and predictors now share a
reviewed import without requiring two manually prepared CSV files.

The [model-guided research note](../../artifacts/bayesian-research-design.md) develops
SUP-019/SUP-020 and future feature proposals against current alloptr capabilities
and primary Bayesian literature. SUP-029 now implements an exact bounded BED
engine in alloptr and a reviewed-model adapter in Suppose. Campaign dispatch,
regression prospective tests, broader losses and learned Action-BED policies remain
separate work. [Implementation evidence](../../artifacts/bed-implementation-evidence.md).


External-model adapters (SUP-017), broader model families, regression-specific
sensitivity/prospective commitments, intended-user acceptance and M3–M4 remain
open. The earlier checkpoints below describe historical increments.

## Implementation checkpoint — September 7, 2026

A working local prototype is now available through `suppose_app()`, the shared R
APIs, and the installed Rapp/ir CLI. See [ACCEPTANCE.md](../../ACCEPTANCE.md) for the
scenario, numerical reference checks, browser evidence, and remaining validation.

The implementation covers the bounded two-condition normal method, attributed
claim revisions, unresolved judgments, predictive inspection, explicit acceptance,
versioned JSON bundles, and manual workbench. SUP-010 and SUP-011 remain partial:
assistant elicitation, corrections, provenance, streamed fixture integration,
and live Muse integration are checked. Domain-user acceptance remains open;
the live walkthrough below found interpretation and conversational issues.
The September 8 observation increment below starts M2; M3–M4 remain unimplemented.

`implemented` below means the stated bounded outcome is implemented and its
checked criteria have evidence in the acceptance report. `partial` means usable
behavior exists but at least one full acceptance criterion remains open.

## Conversation-first correction — September 7, 2026

The default experience is a general shinychat conversation backed by a Deputy
Agent. The temperature form is an optional worked example. The current increment
adds domain-neutral interpretations, qualitative expectations, explicit semantic
acceptance without a numerical model, and saved conversation history. Numerical
methods remain bounded and optional; unsupported questions remain visible.

The implementation uses `suppose_agent()` as shinychat's client, with per-session
inquiry tools and Deputy run provenance. A small Agent subclass handles dynamic
message arguments required by the installed shinychat version while delegating
execution to Deputy. No generic agent runtime is implemented in Suppose.

Validation covers cross-domain interpretations, numerical method eligibility,
no inheritance of unrelated models, user corrections and semantic acceptance.
Live Muse integration is verified, including a saved-record round trip. The
five-response [live walkthrough](../../WALKTHROUGH.md) found a conditional scenario
promoted into an expectation, overly mechanical questioning, and missing units
displayed as `null`. These motivated the SUP-009/SUP-010 fixes and SUP-011 replay
below. An agent-driven walkthrough does not close domain-user acceptance.

### First-session quality checkpoint

The follow-up [implementation and adversarial review](QUALITY-REVIEW.md) adds
complete source statements, separate assistant ideas, direct human correction
with provenance, guarded acceptance, and stable pending proposals. The three
fictional live replays now produce reviewable records and survive JSON round
trips. Live cancellation/retry/decline and keyboard correction/acceptance were
also checked. Unknown-field and quotation failures found during development
were repaired and retained as regression cases.

SUP-027 is complete for the bounded CLI workflow, with a fresh isolated ir/rx
verification and qualitative interpretation inspection. SUP-009/SUP-010/SUP-011
remain partial overall: intended-user quality, broader model behavior, and full
accessibility validation are still open. This checkpoint had 307 passing
expectations. The September 8 increment below supersedes its installation status.

### Observation import checkpoint — September 8

[Observation import and review](OBSERVATIONS-REVIEW.md) completes SUP-012 for the
bounded CSV/data-frame workflow across R, CLI, and the record drawer. Source,
protocol, exposure, units, identities, missingness, and conversion remain attached
to the exact claim revision. Duplicate import and prior-information reuse are
blocked within the declared source/identity boundary. At that checkpoint, M2 had
started and posterior fitting and prospective assessment were still to follow.

This separable implementation proceeded while intended-user acceptance in SUP-011
remains open. A public Shinychat source and fresh isolated ir installation now
work on macOS, including a live Deputy/Muse call. Phone-width layout and the real
CSV upload/download flow were checked. A full screen-reader audit and other
platforms remain open. Current validation: 362 passing expectations and clean
R CMD check.

## Required design and tooling

These are project-wide requirements from the September 7, 2026 design decision,
and apply to every milestone and feature acceptance review.

- **Tidyverse design principles:** design around concrete workflows; use consistent names, argument order, defaults, and return shapes. Favor composable functions with explicit inputs and predictable behavior. Make invalid input actionable and side effects deliberate. Review public APIs against the [tidy design principles](https://design.tidyverse.org/), not only code style.
- **usethis throughout package development:** use its helpers extensively for package setup and ongoing maintenance: dependencies, R/test files, documentation infrastructure, CI, pkgdown, contribution guidance, and release checklists. Preserve existing project content and record setup choices. Use current supported helpers instead of maintaining hand-written equivalents. See [usethis](https://usethis.r-lib.org/).
- **r-lib as the default tooling ecosystem:** use rlang for condition handling where needed, fs for filesystem work, withr for scoped state, testthat and waldo for behavioral tests and comparisons, and pkgload, pkgbuild, rcmdcheck, pak, and pkgdown for their established development jobs. Use callr/processx when process isolation is needed. Declare dependencies according to actual use; development tools belong in the development workflow.
- **cli throughout console communication:** use semantic markup and contextual bullets with `cli::cli_abort()`, `cli::cli_warn()`, and `cli::cli_inform()`, plus cli progress reporting. Preserve condition classes, calls, and structured details so callers and the Shiny interface can handle failures. Keep human diagnostics separate from machine-readable command output; never expose ANSI escapes in browser messages. See [cli](https://cli.r-lib.org/).
- **Shiny and shinychat:** use a thin Shiny/bslib workbench and shinychat for the conversation surface, connected to ellmer and the same domain APIs used from R. Keep review and acceptance explicit. See [shinychat](https://posit-dev.github.io/shinychat/).
- **ir for the CLI:** ship a package executable discoverable by r-lib's `ir`; support `rx` and persistent installation with `ir tool install`. Use Rapp for argument parsing and help metadata, and cli for human output. `ir` is the external launcher/environment tool, not a library to add to DESCRIPTION. Validate the installed executable through ir, not only through Rscript. See [ir package tools](https://r-lib.github.io/ir/tools.html).

SUP-002 establishes these conventions, SUP-009/SUP-010 apply the chat stack,
SUP-026 reviews API and condition consistency, and SUP-027 delivers the CLI.

## Priorities and status

- **P0:** first-session value. These items are specified as bounded work.
- **P1:** observations, prospective assessment, and sensitivity.
- **P2:** broader models, forecasts, decisions, and measurement design.
- **P3:** ecosystem integration, multiple experts, and continuing review.

**Ready** means a bounded task can begin. **Waiting** means its listed
prerequisites must establish the needed contracts first. **Needs-design** means a
later outcome is identified but the implementation approach still needs to be
worked out against concrete examples and current APIs. Acceptance checkboxes below reflect the implemented checkpoint. Completing a prerequisite does not automatically complete
dependent work or its validation.

Stable `SUP-###` IDs identify work across future tracker changes. This file is
the local source of truth until an issue tracker is explicitly established; if
migrated, replace detailed status tracking here with links to the actual issues.

## Milestones

| Milestone | Exit outcome | Work |
|---|---|---|
| M1 — Inspect a belief | A scientist can complete and reopen a reviewed elicitation through the shared R APIs, shinychat workbench, and installed CLI, with a concrete first-session acceptance report. | SUP-001–SUP-011, SUP-026–SUP-027 |
| M2 — Learn from observations | Designated observations update the supported model; prospective tests, sensitivity and fitted model revisions remain inspectable. | SUP-012–SUP-016, SUP-028 |
| M3 — Choose what to investigate | A second domain, external model, decision case, and bounded experiment-design adapter exercise the same concepts. | SUP-017–SUP-020, SUP-029–SUP-033, SUP-036 |
| M4 — Review changes over time | Accepted knowledge and sourced evidence support attributable, consequential reviews across people and decisions. | SUP-021–SUP-025, SUP-034–SUP-035 |

Milestones describe product outcomes, not dates or commitments to finish every
later integration. M4 adapters can be pulled forward when an actual workflow
needs them; their listed dependencies still apply.

## Start here

Close the remaining intended-user walkthrough in [SUP-011](#sup-011). The
locally verifiable P0 implementation and acceptance checks are complete; the
[P0 report](../../artifacts/p0-review.md) records the tested boundaries.

For the current research-design direction, SUP-029, [SUP-030](#sup-030),
[SUP-036](#sup-036), and [SUP-037](#sup-037) are implemented: review a plan,
resume it, freeze and assess future measurements, and inspect sensitivity.
[SUP-020](#sup-020) remains the separate campaign-dispatch integration.
[SUP-031](#sup-031) adds scientifically motivated model alternatives; then
The brms model-world slice in [SUP-038](#sup-038) starts SUP-017; its remaining
adapters and SUP-032 enable richer reference models. Evaluate SUP-033 before committing
to learned Action-BED policies (SUP-034). Equation search (SUP-035) depends on
that validation and prospective loop. These are evidence gates, not calendar promises.

The original foundation sequence below is retained as historical context.

Begin [SUP-001](#sup-001) and [SUP-002](#sup-002). Then run the numerical probe
[SUP-005](#sup-005) alongside the domain and elicitation work
[SUP-003](#sup-003)–[SUP-004](#sup-004). The probe should settle one small statistical
method before a general model interface is designed.

The first complete path is:

`SUP-001/002 → SUP-003/004 + SUP-005 → SUP-006 → SUP-007/008 → SUP-009 → SUP-010 → SUP-011`

The API/condition review in [SUP-026](#sup-026) follows the first implemented
domain operations. The CLI in [SUP-027](#sup-027) then exercises the same APIs.
Both also feed the M1 acceptance gate in SUP-011.

The intended first implementation chunk is the package foundation, scenario,
claim records, elicitation inputs, and numerical probe. That initial chunk is now implemented; the checkpoint above records the wider working prototype.

## Delivery rules

- Preserve original wording, attribution, scope, units, assumptions, and revision references.
- Keep elicited judgments, simulated outcomes, observations, proposed interpretations, and accepted changes distinct.
- Retain incomplete and qualitative formalizations. Do not manufacture numerical confidence.
- Use meaningful reference calculations and failure cases for statistical work. Core tests must work without live model access.
- Verify UI behavior in the running app, including recovery and keyboard use; a passing package check alone is insufficient.
- Keep Suppose responsible for claim meaning and assessment. Evaluate existing ecosystem APIs before introducing adapters; avoid duplicating agent, campaign, or knowledge-store runtimes.
- Keep examples and documentation organization-neutral.

## Index

| ID | Work item | Priority | Status | Dependencies |
|---|---|---|---|---|
| [SUP-001](#sup-001) | Define the first-session acceptance scenario | P0 | implemented | — |
| [SUP-002](#sup-002) | Establish the minimal R package and development checks | P0 | implemented | — |
| [SUP-003](#sup-003) | Represent claims, assumptions, and attributed revisions | P0 | implemented | [SUP-001](#sup-001), [SUP-002](#sup-002) |
| [SUP-004](#sup-004) | Capture elicited judgments with their intended meaning | P0 | implemented | [SUP-003](#sup-003) |
| [SUP-005](#sup-005) | Prove a bounded prior-elicitation method numerically | P0 | implemented | [SUP-001](#sup-001), [SUP-002](#sup-002) |
| [SUP-006](#sup-006) | Construct candidate priors and report elicitation fit | P0 | implemented | [SUP-004](#sup-004), [SUP-005](#sup-005) |
| [SUP-007](#sup-007) | Inspect prior predictions and correct the formalization | P0 | implemented | [SUP-006](#sup-006) |
| [SUP-008](#sup-008) | Save and reopen a complete elicitation record | P0 | implemented | [SUP-003](#sup-003), [SUP-006](#sup-006) |
| [SUP-009](#sup-009) | Deliver the first complete workbench flow | P0 | implemented | [SUP-007](#sup-007), [SUP-008](#sup-008) |
| [SUP-010](#sup-010) | Add an ellmer assistant that proposes reviewable changes | P0 | implemented | [SUP-004](#sup-004), [SUP-006](#sup-006), [SUP-009](#sup-009) |
| [SUP-011](#sup-011) | Validate and document the first-session experience | P0 | partial | [SUP-009](#sup-009), [SUP-010](#sup-010), [SUP-026](#sup-026), [SUP-027](#sup-027) |
| [SUP-012](#sup-012) | Import observations with provenance and evidence roles | P1 | implemented | [SUP-008](#sup-008), [SUP-011](#sup-011) |
| [SUP-013](#sup-013) | Update beliefs from observations and inspect model fit | P1 | implemented | [SUP-006](#sup-006), [SUP-012](#sup-012) |
| [SUP-014](#sup-014) | Commit to and assess a prospective test | P1 | done | [SUP-012](#sup-012), [SUP-013](#sup-013) |
| [SUP-015](#sup-015) | Show sensitivity to prior and likelihood assumptions | P1 | done | [SUP-013](#sup-013) |
| [SUP-016](#sup-016) | Review predictive changes when a model grows | P1 | implemented | [SUP-007](#sup-007), [SUP-013](#sup-013) |
| [SUP-017](#sup-017) | Support a user-supplied model or simulator | P2 | partial | [SUP-008](#sup-008), [SUP-016](#sup-016) |
| [SUP-018](#sup-018) | Demonstrate the same workflow for a product forecast | P2 | needs-design | [SUP-014](#sup-014) |
| [SUP-019](#sup-019) | Connect claims to a decision and its consequences | P2 | needs-design | [SUP-018](#sup-018), [SUP-015](#sup-015) |
| [SUP-020](#sup-020) | Propose a useful next measurement through alloptr | P2 | needs-design | [SUP-014](#sup-014), [SUP-017](#sup-017) |
| [SUP-021](#sup-021) | Store and retrieve accepted records through Graft | P3 | needs-design | [SUP-008](#sup-008), [SUP-011](#sup-011) |
| [SUP-022](#sup-022) | Bring source-grounded research into a claim review | P3 | needs-design | [SUP-012](#sup-012), [SUP-010](#sup-010) |
| [SUP-023](#sup-023) | Retain and compare judgments from multiple experts | P3 | needs-design | [SUP-004](#sup-004), [SUP-008](#sup-008), [SUP-011](#sup-011) |
| [SUP-024](#sup-024) | Review consequential evidence changes over time | P3 | needs-design | [SUP-014](#sup-014), [SUP-021](#sup-021), [SUP-022](#sup-022) |
| [SUP-025](#sup-025) | Review a portfolio of decisions with shared claims | P3 | needs-design | [SUP-019](#sup-019), [SUP-024](#sup-024) |
| [SUP-026](#sup-026) | Review tidyverse API design and consistent cli conditions | P0 | implemented | [SUP-003](#sup-003), [SUP-006](#sup-006) |
| [SUP-027](#sup-027) | Ship the Suppose CLI through ir and rx | P0 | implemented | [SUP-007](#sup-007), [SUP-008](#sup-008), [SUP-026](#sup-026) |
| [SUP-028](#sup-028) | Close a fitted Bayesian model-revision loop | P1 | implemented | [SUP-012](#sup-012), [SUP-013](#sup-013), [SUP-016](#sup-016) |
| [SUP-029](#sup-029) | Review exact Bayesian next-measurement benefits | P1 | implemented | SUP-028 |
| [SUP-030](#sup-030) | Freeze and assess regression-specific future measurements | P1 | implemented | SUP-014, SUP-028, SUP-029 |
| [SUP-031](#sup-031) | Propose scientific interactions and transformations | P1 | ready | SUP-028 |
| [SUP-032](#sup-032) | Connect richer reference models to projection predictive selection | P2 | needs-design | SUP-017, SUP-031 |
| [SUP-033](#sup-033) | Evaluate multi-setting and nonlinear decision designs | P2 | needs-design | SUP-019, SUP-020, SUP-029 |
| [SUP-034](#sup-034) | Evaluate Action-BED learned design and action policies | P3 | needs-design | SUP-017, SUP-033 |
| [SUP-035](#sup-035) | Evaluate Bayesian equation alternatives as experimental hypotheses | P3 | needs-design | SUP-030, SUP-031, SUP-032, SUP-033 |
| [SUP-036](#sup-036) | Review sensitivity of regression and design choices | P1 | implemented | SUP-015, SUP-028, SUP-029 |
| [SUP-037](#sup-037) | Continue a reviewed research plan without rebuilding its form | P1 | implemented | SUP-029 |
| [SUP-038](#sup-038) | Explore the world implied by a model | P1 | in-progress | SUP-008, SUP-017 |

## Work items

<a id="sup-001"></a>

### SUP-001 — Define the first-session acceptance scenario

**Outcome:** A scientist can recognize, correct, and challenge the formal expression of a bounded strength claim before collecting data.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** design · **Status:** implemented

**Depends on:** None

**Acceptance criteria**

- [x] Specify the cure-temperature example with units, formulation, protocol, population, target mean difference, and material threshold; mark illustrative numbers as invented.
- [x] Write a walkthrough from the original words through elicited expectations, predictive inspection, a correction, and an accepted revision.
- [x] Include ambiguous ranges, unsupported causal interpretation, a qualitative-only answer, and inconsistent numerical judgments as explicit cases.
- [x] Record what the first session must demonstrate: recognizable formalization, one consequential assumption, and one concrete challenge. Select a bounded initial model question for SUP-005.

**Verification:** Review the walkthrough against CONCEPT.md and CONTEXT.md; each case has an observable expected outcome.

**Scope boundary:** No full simulator, backend commitment, or demand for two competing models.

<a id="sup-002"></a>

### SUP-002 — Establish the minimal R package and development checks

**Outcome:** Contributors can load, test, and document Suppose consistently before feature code grows.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** foundation · **Status:** implemented

**Depends on:** None

**Acceptance criteria**

- [x] Use usethis extensively to create and maintain package metadata, dependencies, R/test files, documentation, contribution guidance, and development configuration; retain the existing concept, vocabulary, name check, and sticker assets. Record the setup helpers and deliberate deviations.
- [x] Establish the r-lib development workflow with testthat, pkgload/pkgbuild, rcmdcheck, pak, pkgdown, and Air formatting. Use usethis helpers for CI once a remote is configured, with no API credentials required for core checks; use its release-checklist helper when release work begins.
- [x] Keep statistical operations callable directly from R; isolate optional assistant and UI dependencies from the numerical core.
- [x] Document installation and contributor checks, plus public API naming, argument/return conventions, and cli-based condition classes. Apply the required design and tooling section to new functions from the start.

**Verification:** A clean checkout loads and passes R CMD check for the implemented scope; no placeholder assertions presented as feature coverage.

**Scope boundary:** No dependency upgrades across sibling packages, release publication, or broad framework scaffolding.

<a id="sup-003"></a>

### SUP-003 — Represent claims, assumptions, and attributed revisions

**Outcome:** A user can retain their original claim alongside precise, attributable revisions without being forced to assign a probability.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-001](#sup-001), [SUP-002](#sup-002)

**Acceptance criteria**

- [x] Represent original wording, target quantity, units, scope, horizon where relevant, author, assumptions, unresolved questions, and revision ancestry.
- [x] Support incomplete drafts and qualitative beliefs; distinguish an unknown value from an explicit absence.
- [x] Model claim-to-model references as potentially many-to-many; do not require a model to create a claim.
- [x] Preserve earlier accepted records when a person edits scope or meaning; compare revisions in domain terms.

**Verification:** Focused examples cover incomplete drafts, corrected units/scope, separate authors, and a revision without numerical uncertainty.

**Scope boundary:** Use a small domain representation; defer a generic event store, pooling, and collaboration services.

**Delivered:** `record_model_reference()` retains attributed many-to-many references between independent claim objects and candidate priors already retained in a record. References express implications, not fitting or acceptance. Rich external-model adapters remain SUP-017/SUP-032. See [P0 verification](../../artifacts/p0-review.md).

<a id="sup-004"></a>

### SUP-004 — Capture elicited judgments with their intended meaning

**Outcome:** A scientist can express expectations about familiar quantities and see exactly how those answers will be interpreted.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-003](#sup-003)

**Acceptance criteria**

- [x] Capture ranges, quantiles with stated probability levels, comparisons, and qualitative shape judgments at identified conditions.
- [x] Distinguish specimen variation, batch variation, uncertainty in a mean, and uncertainty in a contrast when the chosen scenario requires them.
- [x] Retain original answers, attribution, rationale, source information, and information already observed.
- [x] Detect impossible probability levels, unit mismatches, and contradictory summaries; preserve unresolved answers instead of silently repairing them.

**Verification:** Scenario fixtures demonstrate both valid inputs and targeted requests for clarification; a plausible range never becomes a probability interval implicitly.

**Scope boundary:** No automatic pooling of experts or LLM-generated numerical confidence.

**Delivered:** **Record an expectation** reviews ranges, explicit quantiles, two-condition comparisons and scoped shape answers. `record_judgment()` retains additional answers alongside candidate fitting inputs, without refitting or carrying acceptance onto a new entry. See [P0 verification](../../artifacts/p0-review.md).

<a id="sup-005"></a>

### SUP-005 — Prove a bounded prior-elicitation method numerically

**Outcome:** The team has evidence that one explicit model can translate the selected judgments into inspectable priors.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** spike · **Status:** implemented

**Depends on:** [SUP-001](#sup-001), [SUP-002](#sup-002)

**Acceptance criteria**

- [x] Compare a small set of candidate observation models and prior families for the two-condition strength example; document support and dependence assumptions. Distinguish hard physical restrictions from the disputed claim, and do not hard-code the investigated improvement into every candidate.
- [x] Use known synthetic generating priors to test recovery of elicited summaries and resulting predictive behavior, with seeded computation.
- [x] Include inconsistent summaries and two different priors compatible with sparse judgments; quantify mismatch rather than asserting unique identification.
- [x] Select one initial method with numerical tolerances, supported inputs, failure behavior, and a short rationale. Treat positivity, tails, and observation noise explicitly.

**Verification:** A reproducible script reports reference values, approximation error, predictive checks, and known limitations; synthetic examples remain clearly labeled.

**Scope boundary:** A bounded method decision, not a universal elicitation engine or adoption of every cited research package.

<a id="sup-006"></a>

### SUP-006 — Construct candidate priors and report elicitation fit

**Outcome:** A user can obtain candidate priors whose relationship to their judgments is explicit and reproducible.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-004](#sup-004), [SUP-005](#sup-005)

**Acceptance criteria**

- [x] Implement the selected method behind a small R API with explicit model, prior family, input judgments, and computation settings.
- [x] Return the fitted candidate, elicited-versus-implied summaries, discrepancy measures, seed, and method/version information.
- [x] Expose consequential unconstrained choices and supported alternative fits; keep fitting failure separate from a judgment contradiction.
- [x] Require an explicit accepted revision before a candidate becomes the retained formalization.

**Verification:** Compare outputs with the independent reference cases from SUP-005; include failed fitting and underdetermined inputs.

**Scope boundary:** Fitting elicited judgments does not count as empirical support for the claim.

<a id="sup-007"></a>

### SUP-007 — Inspect prior predictions and correct the formalization

**Outcome:** The scientist can discover an unintended implication of their candidate model before committing to it.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-006](#sup-006)

**Acceptance criteria**

- [x] Show prior predictions in the user's units for the target quantity and observable measurements, with uncertainty sources labeled.
- [x] Compare elicited expectations with implied outcomes and display relevant behavior beyond the directly elicited conditions.
- [x] Allow a supported assumption or judgment to change and show what changed in the predictions, retaining both revisions.
- [x] Provide numeric summaries and readable descriptions alongside plots; do not rely on color alone.

**Verification:** Known example revisions visibly change the appropriate quantity; repeated seeded runs agree and plot summaries match computed results.

**Scope boundary:** No universal model-adequacy score and no claim that simulation validates the external system.

**Delivered:** `check_expectations()` and **Inspect expectations beyond the anchors**
show explicit straight-line projections, elicited-versus-implied quantiles, and
qualitative limitations alongside the original answers. The added projection is
not attributed to the original two judgments. See [P0 verification](../../artifacts/p0-review.md).

<a id="sup-008"></a>

### SUP-008 — Save and reopen a complete elicitation record

**Outcome:** A person can return later and inspect the same accepted belief, inputs, assumptions, and numerical results.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-003](#sup-003), [SUP-006](#sup-006)

**Acceptance criteria**

- [x] Define a versioned local bundle for claim revisions, judgments, candidate models, accepted formalization, and computation provenance.
- [x] Preserve exact referenced revisions and distinguish draft, proposed, and accepted records.
- [x] Round-trip supported records without dropping units, author, unresolved questions, or evidence exposure; record any recomputation explicitly.
- [x] Handle interrupted writes and unsupported schema versions with actionable errors; use safe data serialization rather than executing arbitrary bundle contents.

**Verification:** Save, restart, and reopen the acceptance scenario; compare domain records and stored numerical results, including a failed-write case.

**Scope boundary:** A local single-user format with a clear future adapter boundary, not a replacement generic knowledge platform.

<a id="sup-009"></a>

### SUP-009 — Deliver the first complete workbench flow

**Outcome:** A user can complete the claim-to-accepted-formalization loop in one local interface.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-007](#sup-007), [SUP-008](#sup-008)

**Acceptance criteria**

- [x] Build a thin Shiny/bslib interface over the R APIs: original claim, questions, candidate implications, correction, acceptance, and reopen. Use shinychat for the conversation surface, with the ellmer connection delivered in SUP-010.
- [x] Make the relationship between the original words and current mathematics visible throughout the flow.
- [x] Handle missing answers, incompatible judgments, computation failure, and cancellation without losing the draft. Translate structured conditions into accessible browser messages without leaking ANSI formatting.
- [x] Provide keyboard operation, clear labels, nonvisual plot summaries, and usable layout on a small screen.

**Verification:** Exercise the complete scenario in the running app, including correction and restart; verify keyboard navigation and error recovery directly.

**Scope boundary:** One coherent user journey; no multi-user hosting or general dashboard builder.

**Delivered:** Keyboard review/acceptance, labeled native correlation input, nonvisual prediction summaries, 390px layouts, and browser download/upload were exercised. Upload feedback appears beside the control in the narrow drawer. This is not a claim of full WCAG or screen-reader certification. See [P0 verification](../../artifacts/p0-review.md).

<a id="sup-010"></a>

### SUP-010 — Add an ellmer assistant that proposes reviewable changes

**Outcome:** A person can express a claim conversationally and review the assistant's proposed interpretation before it affects the accepted record.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-004](#sup-004), [SUP-006](#sup-006), [SUP-009](#sup-009)

**Acceptance criteria**

- [x] Connect shinychat to a Deputy Agent over ellmer and expose bounded domain operations for reading a claim, asking for missing meaning, proposing edits, and requesting supported numerical computations; keep orchestration outside the chat widget.
- [x] Show proposed changes and their assumptions; acceptance belongs to the user and cannot be inferred from fluent assistant prose.
- [x] Keep numerical results sourced from statistical procedures; retain tool-result provenance and separate it from explanation.
- [x] Support shinychat streaming, cancellation, retry, decline, correction, unavailable model access, and a usable manual workflow. Interrupted or retried requests must not duplicate accepted changes. Use existing ellmer/Deputy capabilities only where needed.

**Verification:** Deterministic assistant fixtures cover ambiguous ranges, absent probability evidence, unsupported conditions, stale/cancelled tool calls, changed forms and repeated application. Live Muse and scripted Deputy/shinychat paths have completed proposals, explicit review, cancellation and retry. `dev/live-quality.R` exercises three fictional cross-domain cases; `QUALITY-REVIEW.md` records semantic failures, repairs, and remaining quality limits. Intended-user validation remains open.

**Scope boundary:** No arbitrary code execution, silent model expansion, or new generic agent runtime.

**Delivered:** The current scripted Deputy/shinychat browser path covers streaming, decline, cancellation, retry, correction and unavailable-model manual recovery. The adapter resets a reused cancelled controller only after Deputy accepts a fresh stream. Saved artifacts prove cancellation preserves revisions and retry applies once. See [P0 verification](../../artifacts/p0-review.md).

<a id="sup-011"></a>

### SUP-011 — Validate and document the first-session experience

**Outcome:** The first milestone is supported by a demonstrated user journey and a runnable introduction.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** validation · **Status:** partial

**Depends on:** [SUP-009](#sup-009), [SUP-010](#sup-010), [SUP-026](#sup-026), [SUP-027](#sup-027)

**Acceptance criteria**

- [x] Provide a concise quickstart and self-contained example that works without a paid model, with consistent R and CLI results; document the shinychat/ellmer path and ir launch/install workflow. Prepare package documentation with usethis and pkgdown.
- [x] Run the SUP-001 scenarios end to end and retain evidence of the visible outcomes, including limitations.
- [ ] Conduct a walkthrough with an intended scientist or engineer when available; record whether they recognize the formalization and can identify an assumption and a challenge.
- [x] Review accessibility, tidyverse API consistency, cli diagnostics, package checks, the installed ir executable, and scientific wording. If a domain-user walkthrough has not occurred, report that gap and leave user validation open.

**Verification:** Runnable tutorial, passing checks for implemented behavior, and an explicit acceptance report separating automated evidence from observed user feedback.

**Scope boundary:** Do not substitute a successful demo for a claim of product-market fit or statistical calibration in the field.

<a id="sup-012"></a>

### SUP-012 — Import observations with provenance and evidence roles

**Outcome:** A user can add real measurements without confusing them with elicited expectations or simulated outcomes.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-008](#sup-008), [SUP-011](#sup-011)

**Acceptance criteria**

- [x] Import a documented tabular form with conditions, units, batch or specimen identity as needed, protocol, and observation times.
- [x] Record source, transformations, missingness, duplicates, and the role of each dataset in model construction or assessment.
- [x] Flag observations already incorporated into the elicited prior or used during exploration so reuse cannot be presented as independent testing.
- [x] Retain simulation outputs as a distinct record type with identified model and run settings.

**Verification:** Fixtures cover unit conversion, replicated batches, missing outcomes, duplicate records, and attempted double use of information.

**Scope boundary:** A narrow supported import path first; no universal data integration service.
Source identity and exposure are declarations, not authenticated proof. Related
measurements under different source IDs are not automatically recognized. There
is no data reclassification/correction API yet; use an earlier saved record.
See [OBSERVATIONS-REVIEW.md](OBSERVATIONS-REVIEW.md) for evidence and limits.

<a id="sup-013"></a>

### SUP-013 — Update beliefs from observations and inspect model fit

**Outcome:** A scientist can see how designated observations change the target quantity and whether the model describes those observations adequately.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** implemented for the bounded normal model

**Depends on:** [SUP-006](#sup-006), [SUP-012](#sup-012)

**Acceptance criteria**

- [x] Fit the initial supported model using the identified prior and observation revisions, retaining inference settings and diagnostics.
- [x] Show prior and posterior summaries for the claim's target quantity and separate these from predictive checks of measurements.
- [x] Report computation failure, inadequate diagnostics, and observed model mismatch as distinct outcomes.
- [x] Retain the original formalization and present any proposed model revision separately from the fitted result.

**Verification:** Reference cases compare with analytical or independently implemented calculations where available; include data generated outside the assumed model.

**Scope boundary:** Do not present a posterior probability as unconditional proof of a claim.

<a id="sup-014"></a>

### SUP-014 — Commit to and assess a prospective test

**Outcome:** A user can distinguish an exploratory fit from a prediction assessed against outcomes designated in advance.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** done

**Depends on:** [SUP-012](#sup-012), [SUP-013](#sup-013)

**Acceptance criteria**

- [x] Freeze identified claim, model, prior/data basis, predictions, protocol, horizon, and assessment rule before the designated outcomes are examined.
- [x] Record evidence exposure and make later changes new revisions; a timestamp alone does not establish lack of prior exposure.
- [x] Assess missing, incomplete, and inconclusive outcomes explicitly and retain results for the original commitment.
- [x] Support both an intervention and a future observational outcome, with conclusions limited by the evidence design.

**Verification:** A lifecycle example commits, ingests later outcomes, assesses, and revises without changing the earlier commitment; include horizon and missing-data cases.

**Delivered:** `/test` and **Record → A future test**, portable commitments and assessments, exact planned-cohort rules, CSV templates, frozen prediction plots, and a synthetic lifecycle. See [verification report](../../artifacts/prospective-review.md).

**Scope boundary:** No blanket claim that preregistration alone establishes validity or controls error rates.

<a id="sup-015"></a>

### SUP-015 — Show sensitivity to prior and likelihood assumptions

**Outcome:** The user can identify when their conclusion depends heavily on a specified prior or observation-model assumption.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** done

**Depends on:** [SUP-013](#sup-013)

**Acceptance criteria**

- [x] Select supported perturbations and output quantities; evaluate priorsense as an adapter against current package APIs before choosing an implementation.
- [x] Show changes in the target estimate and any attached assessment, with the perturbation scope visible.
- [x] Report failed or unreliable sensitivity computations and distinguish prior-strength changes from alternative prior shapes or models.
- [x] Connect a consequential sensitivity finding to a concrete follow-up question or model review.

**Verification:** Known sensitive and insensitive examples produce the expected changes; supported numerical calculations agree with a reference implementation.

**Delivered:** `/sensitivity` and **Record → Check sensitivity**, exact normal power scaling, saved comparisons and follow-up drafting, with a priorsense adapter evaluation. See [verification report](../../artifacts/sensitivity-review.md).

**Scope boundary:** No global robustness certificate from a local power-scaling check.

<a id="sup-016"></a>

### SUP-016 — Review predictive changes when a model grows

**Outcome:** Adding a variable or interaction does not silently change the substantive expectations a user accepted.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-007](#sup-007), [SUP-013](#sup-013)

**Acceptance criteria**

- [x] Compare prior predictive implications of the old and proposed model under aligned conditions and target quantities.
- [x] Make new dependencies and prior assumptions visible, including predictive values that become implausible.
- [x] Retain the scientific reason for changing the model and require review of changed implications.
- [x] Demonstrate one model extension using sensible predictive scaling; document where automatic adjustment is unsupported.

**Verification:** A controlled extension exposes inflated predictions under a naive prior and records the reviewed alternative without rewriting history.

Implemented one shared additive predictor, raw-unit versus meaningful-change
coefficient scaling, aligned outcomes and matched contrasts, visible projection
assumptions, and saved reviewed alternatives. Real chat tools populate extension
and sensitivity forms, preserve omitted values, protect concurrent edits and
restore pending previews. See [acceptance evidence](../../artifacts/extension-review.md).
Extended-model fitting, interactions and automatic prior adjustment are unsupported.

**Scope boundary:** Predictive consistency does not establish equivalence of mechanisms or eliminate scientific model comparison.

<a id="sup-017"></a>

### SUP-017 — Support a user-supplied model or simulator

**Outcome:** A scientist can reuse a model they already trust while preserving Suppose's claim and evidence semantics.

**Priority:** P2 · **Milestone:** M3 — Choose what to investigate · **Type:** design · **Status:** partial

**Depends on:** [SUP-008](#sup-008), [SUP-016](#sup-016)

**Acceptance criteria**

- [x] Define a narrow adapter contract for conditions, units, unknown quantities, predictions, run provenance, and computation failures.
- [ ] Demonstrate a simple external R model and an expensive-simulator fixture through that same contract.
- [x] Declare which uncertainty sources and elicitation operations the adapter supports; unsupported capabilities remain explicit.
- [x] Retain the distinction between a simulation run and observations of the external system it represents.

**Delivered slice:** SUP-038 implements a bounded brms prediction adapter and
three bundled model-world examples, with portable simulation artifacts and
reviewed implications. Generic R simulators, expensive-simulator execution,
Stan and tidymodels adapters remain open.

**Verification:** Two concrete adapters pass shared behavioral examples without a bespoke host runtime.

**Scope boundary:** Resolve the adapter shape from examples; defer arbitrary distributed execution and every modeling framework.

<a id="sup-018"></a>

### SUP-018 — Demonstrate the same workflow for a product forecast

**Outcome:** A team can examine and assess a bounded purchase-rate claim using the same core records as the laboratory example.

**Priority:** P2 · **Milestone:** M3 — Choose what to investigate · **Type:** feature · **Status:** needs-design

**Depends on:** [SUP-014](#sup-014)

**Acceptance criteria**

- [ ] Implement the generic migration-service example with a defined eligible population, offer, price, purchase event, and horizon.
- [ ] Distinguish uncertainty about purchase probability from variation in cohort outcomes and from changing future conditions.
- [ ] Separate conditional scenarios from forecasts, and interview reports from observed purchase behavior.
- [ ] Close the horizon and assess the forecast, retaining missing coverage, changed populations, and scope limitations.

**Verification:** An end-to-end example handles a completed cohort, an incomplete horizon, and a population change without laboratory-specific schema changes.

**Scope boundary:** No organization-specific examples, causal claims from observational purchase records, or immediate market-monitoring platform.

<a id="sup-019"></a>

### SUP-019 — Connect claims to a decision and its consequences

**Outcome:** A user can see which uncertain assumption could change a choice between concrete options.

**Priority:** P2 · **Milestone:** M3 — Choose what to investigate · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-018](#sup-018), [SUP-015](#sup-015)

**Acceptance criteria**

- [ ] Represent options, consequences, criteria, attributable preferences, and dependencies on multiple claims.
- [ ] Use the migration-service example to connect adoption, delivery effort, support burden, and economics with shared drivers visible.
- [ ] Compare decisions under stated scenarios and show which uncertainty changes the preferred option.
- [ ] Provide quantitative value-of-information analysis only where model and preferences support it; preserve qualitative comparisons otherwise.

**Current evidence:** SUP-029 implements the bounded two-protocol linear utility
case with an explicit outcome-equivalent threshold and experiment costs. This
item remains open for multiple claims/options, nonlinear consequences, preference
elicitation and actual economics.

**Verification:** A worked case shows why the largest uncertainty can differ from the most decision-relevant one and keeps evidence strength separate from preferences.

**Scope boundary:** No universal opportunity score or automatic authorization of a consequential action.

<a id="sup-020"></a>

### SUP-020 — Propose a useful next measurement through alloptr

**Outcome:** A scientist can choose a feasible measurement that serves an explicit learning purpose.

**Priority:** P2 · **Milestone:** M3 — Choose what to investigate · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-029](#sup-029), [SUP-030](#sup-030); SUP-017 for broader models

**Acceptance criteria**

- [ ] Map a bounded Suppose claim and model to current alloptr campaign and experimental-space concepts after inspecting its public APIs.
- [ ] Declare whether the objective is estimation, discrimination, inadequacy detection, or outcome improvement; include cost, noise, replication, and feasibility.
- [ ] Return candidate actions with a stated expected learning benefit and limits, including an honest no-informative-design outcome.
- [ ] Record proposal, user acceptance, actual execution, and resulting observations as separate steps.

**Current evidence:** SUP-029 uses alloptr's new exact scoring engine, but does not
create campaign proposals. This item owns the remaining campaign adapter: map
feasible candidate IDs and replicate counts to experimental spaces, enforce campaign
budgets/constraints independently, retain proposal/acceptance/execution/observation
links, and reject stale model/campaign state. Do not count a saved Suppose plan as
a dispatched alloptr proposal.

**Verification:** An example includes two mean curves whose noisy measurements are hard to distinguish and a replication or intervention that changes what can be learned.

**Scope boundary:** No campaign-runtime reimplementation inside Suppose; decision-value ranking additionally depends on SUP-019.

<a id="sup-021"></a>

### SUP-021 — Store and retrieve accepted records through Graft

**Outcome:** A reviewed Suppose formalization can be retained and retrieved through the ecosystem's knowledge layer with its meaning intact.

**Priority:** P3 · **Milestone:** M4 — Review changes over time · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-008](#sup-008), [SUP-011](#sup-011)

**Acceptance criteria**

- [ ] Inspect current Graft APIs and define the smallest adapter for accepted Suppose records and exact referenced revisions.
- [ ] Round-trip claim meaning, judgments, model/data basis, assessment role, and acceptance provenance.
- [ ] Demonstrate retrieval of an earlier accepted revision without substituting the current revision or crossing an owner boundary.
- [ ] Document which lifecycle and storage semantics belong to the host and Graft, and which domain validations remain in Suppose.

**Verification:** A concrete adapter proof compares local and Graft-backed records and exercises stale references and two owners.

**Scope boundary:** No new generic knowledge store; host authentication and deployment remain separate work.

<a id="sup-022"></a>

### SUP-022 — Bring source-grounded research into a claim review

**Outcome:** A user can consider relevant published evidence without treating an assistant's summary as an observation.

**Priority:** P3 · **Milestone:** M4 — Review changes over time · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-012](#sup-012), [SUP-010](#sup-010)

**Acceptance criteria**

- [ ] Inspect current Tempest outputs and map identified source records and supporting passages into a Suppose review proposal.
- [ ] Retain source origin, dates, scope, uncertainty, and supporting or challenging role for the target claim.
- [ ] Detect repeated reports of one underlying source and distinguish an announcement from realized outcomes.
- [ ] Keep proposed interpretation separate from user-accepted changes and explicitly record prior exposure to the evidence.

**Verification:** A bounded example uses supporting, contradicting, duplicated, and weakly relevant sources with traceable citations.

**Scope boundary:** No automatic truth assignment or duplicate research orchestration framework.

<a id="sup-023"></a>

### SUP-023 — Retain and compare judgments from multiple experts

**Outcome:** Different people can disagree about a shared claim without their beliefs being silently merged.

**Priority:** P3 · **Milestone:** M4 — Review changes over time · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-004](#sup-004), [SUP-008](#sup-008), [SUP-011](#sup-011)

**Acceptance criteria**

- [ ] Keep judgments, rationales, models, and accepted revisions attributable to each contributor.
- [ ] Compare observable implications under aligned scopes and flag differences in interpretation before summarizing disagreement.
- [ ] If pooling is offered, require an explicit selected method with assumptions, influence, and sensitivity shown.
- [ ] Define ownership and access requirements from a concrete shared-review scenario before choosing collaboration infrastructure.

**Verification:** An example preserves two disagreeing experts and demonstrates how a proposed pooling method changes predictions.

**Scope boundary:** No majority vote as proof, silent pooling, or assumption that local persistence already provides multi-user isolation.

<a id="sup-024"></a>

### SUP-024 — Review consequential evidence changes over time

**Outcome:** A user can see which new evidence warrants revisiting an accepted belief or decision.

**Priority:** P3 · **Milestone:** M4 — Review changes over time · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-014](#sup-014), [SUP-021](#sup-021), [SUP-022](#sup-022)

**Acceptance criteria**

- [ ] Define review triggers and connect new evidence to the exact earlier expectation and assessment.
- [ ] Distinguish no relevant change from failed checks, incomplete coverage, and missing outcomes.
- [ ] Retain event, publication, observation, and assessment times; separate a changed world from a mistaken earlier belief.
- [ ] Present proposed revisions for review, preserving accepted history and any affected decision dependencies.

**Verification:** A replay covers duplicated reports, delayed publication, regime change, failed collection, and a consequential new observation.

**Scope boundary:** A bounded review workflow first; no unrequested source monitoring, notifications, or autonomous consequential action.

<a id="sup-025"></a>

### SUP-025 — Review a portfolio of decisions with shared claims

**Outcome:** A team can identify which decision needs attention and why when several choices depend on shared beliefs.

**Priority:** P3 · **Milestone:** M4 — Review changes over time · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-019](#sup-019), [SUP-024](#sup-024)

**Acceptance criteria**

- [ ] Connect cases to shared claims, owners, deadlines, dependencies, and accepted revisions without copying belief state.
- [ ] Explain attention requests using changed evidence, upcoming horizons, and decision consequences.
- [ ] Retain separate criteria and unknowns instead of inventing a universal ranking score.
- [ ] Demonstrate how one accepted claim revision affects two decision cases while preserving their different preferences.

**Verification:** A small portfolio walkthrough shows both an affected decision and one that needs no change, with the reasoning traceable.

**Scope boundary:** Defer generalized work routing and organization-wide deployment until the bounded review flow is demonstrated.

<a id="sup-026"></a>

### SUP-026 — Review tidyverse API design and consistent cli conditions

**Outcome:** The same operation is predictable from R, the workbench, and the CLI, and failures tell users what they can correct.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** validation · **Status:** implemented

**Depends on:** [SUP-003](#sup-003), [SUP-006](#sup-006)

**Acceptance criteria**

- [x] Review the implemented claim and elicitation APIs against concrete workflows and tidyverse design principles: coherent names and argument order, predictable return types, explicit side effects, and composable operations. Fix inconsistencies in the APIs themselves.
- [x] Use cli for errors, warnings, messages, and progress, with stable condition classes and useful argument, unit, and revision context. Preserve the relevant call and structured fields for programmatic handling.
- [x] Use established r-lib packages for condition propagation, scoped state, paths, and tests where appropriate. Avoid parallel home-grown utilities for jobs those packages already cover.
- [x] Exercise malformed inputs, missing files, incompatible units, failed numerical fitting, and interrupted work; verify useful plain-text output without color and correct handling in Shiny without ANSI escapes.

**Verification:** Behavioral tests assert condition classes and structured details; focused snapshots cover user-facing wording. Review an end-to-end script for API consistency and record resolved findings.

**Scope boundary:** This acceptance review supplements conventions enforced throughout development; it is not a reason to defer good API design or cli adoption until the end.

<a id="sup-027"></a>

### SUP-027 — Ship the Suppose CLI through ir and rx

**Outcome:** A user can inspect and reproduce a saved elicitation from a terminal using the same package operations as the workbench.

**Priority:** P0 · **Milestone:** M1 — Inspect a belief · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-007](#sup-007), [SUP-008](#sup-008), [SUP-026](#sup-026)

**Acceptance criteria**

- [x] Provide an `exec/suppose` package executable using Rapp argument parsing and help metadata. Keep command handlers thin wrappers over the public R APIs. Declare required R package dependencies; treat ir as external tooling.
- [x] Support a bounded initial workflow: inspect a saved record, run supported predictive computation with an explicit seed, and export results. Specify clear command help, required inputs, and deliberate file-write behavior.
- [x] Use cli for contextual diagnostics and progress on stderr; keep machine-readable stdout clean. Define exit statuses, noninteractive behavior, cancellation, and operation without color or a TTY.
- [x] Verify package discovery and execution via `rx --from <package-ref> suppose --help` and a launcher installed using `ir tool install <package-ref>`. Use the actual development artifact or configured repository reference and isolated temporary tool/library locations in tests.
- [x] Document both launch paths and exercise a successful computation and an invalid-input failure through the installed launcher. Show that returned values and persisted revisions agree with the equivalent R calls.

**Verification:** Smoke-test the packaged executable in an ir-managed environment, including paths with spaces, stdout/stderr separation, nonzero failure status, and no reliance on the developer's user library. Test supported operating systems in CI once configured.

**Scope boundary:** The initial CLI is a reproducible command workflow. A full terminal chat UI is separate future work; do not duplicate the numerical core, parser, or package environment manager.

## Already established

- Working project name and directory: `suppose`.
- Concept and domain vocabulary, including the prior-elicitation loop.
- Dated package [name check](NAME-CHECK.md).
- Hex sticker and reproducible artwork/rendering files.

These are project setup artifacts, not completed implementation milestones.

<a id="sup-028"></a>

### SUP-028 — Close a fitted Bayesian model-revision loop

**Outcome:** A person can inspect a failed predictive implication, add a predictor,
fit the revision and retain a reasoned comparison without rewriting earlier work.

**Priority:** P1 · **Milestone:** M2 — Learn from observations · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-012](#sup-012), [SUP-013](#sup-013), [SUP-016](#sup-016)

**Acceptance criteria**

- [x] Link numeric predictors to retained outcome IDs with source, units and revision references.
- [x] Review a proper regression prior and fit unknown common measurement variance.
- [x] Show coefficient/predictive uncertainty, residual patterns and joint predictive checks with simulation uncertainty.
- [x] Compare an added predictor on identical outcomes using fixed-prior exact leave-one-out refits and paired score uncertainty.
- [x] Retain original and revised fits, diagnostics, an explicit choice including neither, and the scientific reason.
- [x] Provide real chat form drafting, protected edits, native restoration, portable records and installed CLI inspection.

**Verification:** The synthetic temperature/duration example exposes an omitted
predictor, improves held-out prediction after revision, and retains a borderline
tail check as unresolved. Independent marginal-likelihood ratios verify every
LOO score. Saved records reconstruct both original scientific bases and preserve
shared priors and baseline fit results. See [report](../../artifacts/regression-review.md).

**Scope boundary:** One or two numeric predictors, independent Gaussian outcomes,
normal/inverse-gamma prior and exact inference. No interactions, hierarchical
models, arbitrary simulators, general samplers or automatic claims of adequacy.
Predictive model selection is exploratory; regression-specific prospective
commitments and power sensitivity remain separate work.

<a id="sup-029"></a>

### SUP-029 — Review exact Bayesian next-measurement benefits

**Outcome:** A person can compare alternative measurements against a stated mean
contrast or a choice between two protocols, and retain a reasoned planning choice.

**Priority:** P1 · **Milestone:** M3 · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-028](#sup-028)

**Acceptance criteria**

- [x] Use the retained model's joint normal/inverse-gamma posterior and its original predictor transforms; integrate unknown noise.
- [x] alloptr computes exact expected contrast-variance reduction and two-action expected opportunity-loss reduction for independent replicated settings.
- [x] Distinguish a scientific usefulness threshold from an explicit linear utility preference, and experiment costs from downstream protocol penalties.
- [x] Restrict choices to user-declared feasibility and the unit budget; show ties, extrapolation flags, and no positive net-benefit outcome.
- [x] Chat prepares a reviewable form; preserve edited controls, model checks, source model identity, and a separate human planning choice.
- [x] Verify actual chat preparation, human review, saved records and native reopening in the fictional coating example.

**Evidence and verification:** [Derivation and primary-source review](../../artifacts/bed-implementation-evidence.md).
Independent Student-t quadrature and matrix precision updates verify alloptr's
scores. Tests cover costs, budget, no-information designs, replication, stale
reviews, provenance and JSON round trips. Live chat, pending-draft restoration, human retention and native reopening passed;
see [acceptance evidence](../../artifacts/bed-review.md).

**Scope boundary:** One-step, single-setting replicate alternatives, one mean
contrast and two linear-utility actions. No policy training, multi-setting batch
search, information-gain estimator or model-discrimination score. Planning reviews
are not alloptr campaign proposals, execution records or frozen prospective tests.

<a id="sup-030"></a>

### SUP-030 — Freeze and assess regression-specific future measurements

**Outcome:** A reviewed research plan becomes a genuinely prospective check with
immutable predictions, collection rules and later assessment.

**Priority:** P1 · **Milestone:** M3 · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-014](#sup-014), [SUP-028](#sup-028), [SUP-029](#sup-029)

**Acceptance criteria**

- [x] Freeze fit/model ID, target, exact future IDs and settings, independent-unit/assignment protocol, deadline and an explicit assessment rule before observations are seen.
- [x] Retain joint predictive dependence and unknown noise; distinguish population-mean targets from future-observation intervals and specify multiplicity for joint checks.
- [x] Require eligible unseen evidence with matching units/protocol; handle incomplete batches, corrected observations and expired deadlines without rewriting commitments.
- [x] Keep design utility, predictive adequacy and causal claims distinct; declining a plan never creates a commitment.
- [x] Expose review/freeze/assessment in chat-assisted forms and saved records.

**Implementation evidence:** [Research-loop acceptance](../../artifacts/research-loop-review.md)
and the executable [continue, test and sensitivity guide](../../vignettes/research-loop.Rmd).

**Original motivating evidence:** The coating walkthrough exposed incorrect routing to fixed-noise
`/test`; current BED proposals explicitly remain uncommitted. [Walkthrough](../../artifacts/chat-walkthrough/review.md),
[Bayesian workflow](../../artifacts/bayesian-research-design.md).

**Verification:** Commit, collect, assess and reopen a randomized fixed-time
coating comparison. Changing the model later cannot change the frozen prediction;
reused pilot data cannot satisfy the test. Compare simultaneous coverage against
joint simulation under a known synthetic model.

**Scope boundary:** Support the existing regression family first; no universal
causal validation or generic sequential-testing guarantee.

<a id="sup-031"></a>

### SUP-031 — Propose scientific interactions and transformations

**Outcome:** Chat can suggest an interpretable model revision tied to a mechanism,
then expose its implications and assumptions for review.

**Priority:** P1 · **Milestone:** M3 · **Type:** feature · **Status:** ready

**Depends on:** [SUP-028](#sup-028)

**Acceptance criteria**

- [ ] Represent derived features separately from newly measured predictors, with immutable source columns, expression, units, domain restrictions and scientific rationale.
- [ ] Start with temperature-by-time interaction retaining both main effects, plus a small reviewed transform set; never apply kinetic temperature transforms directly to Celsius.
- [ ] Show induced prior predictions and meaningful-change scales before fitting; preserve the original additive model and unchanged prior components where mathematically possible.
- [ ] Show where competing models disagree over feasible settings and retain model-check failures; do not label an improved LOO score a discovered mechanism.
- [ ] Keep search history and require validation matching the intended generalization; fitting transformations on outcomes belongs inside selection/validation.

**Evidence:** [Scientific feature workflow and 2025 projection predictive review](../../artifacts/bayesian-research-design.md).
The current coating data motivate an interaction question, not evidence that an
interaction is present. Current regression supports only two raw numeric predictors.

**Verification:** Additive and interacting synthetic generators yield distinct
checks and prediction surfaces; invalid-domain and unit mistakes fail early.
A reviewer can recover the original model and all prior proposals.

**Scope boundary:** No unrestricted formula generation, symbolic discovery or
automatic selection from repeated LOO searches.

<a id="sup-032"></a>

### SUP-032 — Connect richer reference models to projection predictive selection

**Outcome:** A well-checked richer model guides a smaller or cheaper set of
predictors without discarding uncertainty over predictions.

**Priority:** P2 · **Milestone:** M3 · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-017](#sup-017), [SUP-031](#sup-031)

**Acceptance criteria**

- [ ] Define the external-model adapter for joint posterior predictions, likelihood/noise, diagnostics, transforms, identity and supported design calculations.
- [ ] Start with a supported brms/rstanarm/projpred path and scientifically regularized reference model; expose family-specific limitations.
- [ ] Compare projected submodels against the reference, including measurement burden and correlated substitute predictors.
- [ ] Separate constructing features, selecting features and buying new measurements; use grouped/time/nested validation where the target demands it.
- [ ] Retain reference and projected models, search provenance and predictive failures.

**Evidence:** [McLatchie et al., Statistical Science 2025](https://acris.aalto.fi/ws/portalfiles/portal/176405756/Advances_in_Projection_Predictive_Inference.pdf),
[official projpred workflow](https://mc-stan.org/projpred/articles/projpred.html).

**Verification:** A correlated-predictor example preserves predictions with fewer
measurements without claiming the selected predictor is causally unique. Validate
selection inside outer folds and exercise an unsupported model-family failure.

**Scope boundary:** No selection-based causal importance or automatic guarantee
that a poorly checked reference model is adequate.

<a id="sup-033"></a>

### SUP-033 — Evaluate multi-setting and nonlinear decision designs

**Outcome:** A campaign can compare complete experimental batches for decisions
that the exact two-action, single-setting design cannot represent.

**Priority:** P2 · **Milestone:** M3 · **Type:** design · **Status:** needs-design

**Depends on:** [SUP-019](#sup-019), [SUP-020](#sup-020), [SUP-029](#sup-029)

**Acceptance criteria**

- [ ] Extend alloptr's design capability contract to multi-setting batches with full joint covariance, common noise and explicit cost/budget constraints.
- [ ] Separate estimation, model discrimination and downstream decision loss; declare required posterior/simulator/utility interfaces per criterion.
- [ ] For nonlinear loss, report numerical error and ranking uncertainty using paired simulations; never subtract costs in incompatible units.
- [ ] Include a no-experiment action; account for replication, batching, setup costs and nonexchangeable unit structure where supported.
- [ ] Compare approximations with SUP-029's exact oracle on its supported special case.

**Evidence:** [BED derivation and Action-BED assessment](../../artifacts/bed-implementation-evidence.md).
Fixed-target zero-cost exact criteria can share the same candidate ordering;
changing the purpose is not guaranteed to change the best setting.

**Verification:** An interaction-discrimination case and a nonlinear utility case
require different designs; mean-curve separation alone fails when observation
noise makes the models indistinguishable. Increasing simulations stabilizes
estimates and a numerical tie remains visible.

**Scope boundary:** No unsupported joint-noise assumption hidden behind a generic
simulator interface; no trained policy required for the first finite-batch method.

<a id="sup-034"></a>

### SUP-034 — Evaluate Action-BED learned design and action policies

**Outcome:** Evidence determines whether learned task-specific policies improve
repeated or sequential research enough to justify their training and complexity.

**Priority:** P3 · **Milestone:** M4 · **Type:** research spike · **Status:** needs-design

**Depends on:** [SUP-017](#sup-017), [SUP-033](#sup-033)

**Acceptance criteria**

- [ ] Implement or reproduce the primary paper's joint design/action policy objective using a verifiable source revision and documented deviations.
- [ ] Declare simulator, differentiability/estimator requirements, loss, feasible design space and training distribution; separate training from held-out evaluation.
- [ ] Benchmark achieved decision loss, training cost and per-design latency against exact SUP-029, finite Monte Carlo BED, random and conventional designs.
- [ ] Test out-of-distribution models, simulator misspecification, budgets and stochastic seeds; expose uncertainty and failure conditions.
- [ ] Advance only if a repeated-campaign or sequential use case demonstrates material advantage after training cost; record a negative result otherwise.

**Evidence:** [Action-BED, June 2026 preprint](https://arxiv.org/abs/2606.23662),
[UAI 2026 score-matching BED](https://proceedings.mlr.press/v337/phillips26a.html),
[local tractability assessment](../../artifacts/bed-implementation-evidence.md).
A public implementation was not located during this assessment; do not label
our exact method a paper reproduction.

**Verification:** Independent held-out simulations and exact special-case oracles;
report the whole compute/quality tradeoff and reproducible seeds/configurations.

**Scope boundary:** Research spike, not production readiness or automatic research
execution. Policies must not overwrite human scientific/utility assumptions.

<a id="sup-035"></a>

### SUP-035 — Evaluate Bayesian equation alternatives as experimental hypotheses

**Outcome:** Plausible equations produce discriminating future experiments while
preserving uncertainty over expressions and the history of the search.

**Priority:** P3 · **Milestone:** M4 · **Type:** research spike · **Status:** needs-design

**Depends on:** [SUP-030](#sup-030), [SUP-031](#sup-031), [SUP-032](#sup-032), [SUP-033](#sup-033)

**Acceptance criteria**

- [ ] Compare a bounded symbolic-regression method against reviewed scientific features and regularized reference models.
- [ ] Retain multiple expressions, parameter uncertainty, units/domain restrictions, operator priors and search provenance.
- [ ] Report uncertainty conditional on screened feature spaces; fit preprocessing and data-derived prior scales within validation where required.
- [ ] Use disagreement to propose a prospective discriminating experiment; do not call the leading expression a discovered true mechanism.

**Evidence:** [ERRLESS, UAI 2026](https://proceedings.mlr.press/v337/boussif26a.html),
[Bayesian SISSO, June 2026 preprint](https://arxiv.org/html/2606.04042v2),
[source-specific limitations](../../artifacts/bayesian-research-design.md).

**Verification:** Synthetic recoverable and nonidentifiable mechanisms, noisy
small-data benchmarks, untouched prospective measurements, and comparison with
simpler baselines. Distinguish posterior approximation quality from prediction.

**Scope boundary:** No unconstrained automatic mechanism discovery or posterior
claims covering expressions discarded before the Bayesian stage.

<a id="sup-036"></a>

### SUP-036 — Review sensitivity of regression and design choices

**Outcome:** A person sees whether plausible model/prior choices change the
scientific conclusion or recommended next experiment.

**Priority:** P1 · **Milestone:** M3 · **Type:** feature · **Status:** implemented

**Depends on:** [SUP-015](#sup-015), [SUP-028](#sup-028), [SUP-029](#sup-029)

**Acceptance criteria**

- [x] Define supported prior/likelihood perturbations for the normal/inverse-gamma model, preserving their exact mathematical meaning and properness.
- [x] Compare mean contrasts, noise, predictive checks and design benefits using identical rows, candidate settings and utility assumptions.
- [x] Distinguish utility sensitivity from model sensitivity; show when rankings are effectively tied or a recommendation changes.
- [x] Retain variants separately without changing original model reviews or frozen tests; expose a regression-specific chat-assisted review flow.

**Implementation evidence:** [Research-loop acceptance](../../artifacts/research-loop-review.md)
and the executable [continue, test and sensitivity guide](../../vignettes/research-loop.Rmd).

**Original motivating evidence:** The live coating walkthrough initially proposed a slope prior too
tight for plausible useful gains; its final model check remained borderline.
[Walkthrough](../../artifacts/chat-walkthrough/review.md), [BED evidence](../../artifacts/bed-implementation-evidence.md).

**Verification:** A deliberately prior-sensitive small dataset changes the design
recommendation under a specified perturbation; a well-informed case remains
stable. Independent analytic checks verify each supported perturbation.

**Scope boundary:** No claim of robustness from trying a few variants, and no
reuse of the older fixed-noise sensitivity form for unsupported regressions.

<a id="sup-037"></a>

### SUP-037 — Continue a reviewed research plan without rebuilding its form

**Outcome:** Reopening a plan makes its assumptions easy to reuse and revise.

**Priority:** P1 · **Milestone:** M3 · **Type:** usability · **Status:** implemented

**Depends on:** [SUP-029](#sup-029)

**Acceptance criteria**

- [x] Provide an explicit action to start a new draft from a retained plan, restoring its actual reviewed candidate settings, target, costs, budget and preferences.
- [x] Preserve the original planning review and require a fresh comparison and review when any consequential setting changes.
- [x] Keep the candidate comparison and model limitations prominent; place CSV editing and numerical details behind optional controls.
- [x] Allow chat to revise one assumption without re-entering the others, while preserving concurrent manual edits and identifying stale source models.

**Implementation evidence:** [Research-loop acceptance](../../artifacts/research-loop-review.md)
and the executable [continue, test and sensitivity guide](../../vignettes/research-loop.Rmd).

**Original motivating evidence:** Native reopening in the [BED acceptance](../../artifacts/bed-review.md)
preserved the reviewed plan exactly, but a new form still starts blank. The saved
review is inspectable; continuing it is more work than it should be.

**Verification:** Reopen the coating plan, change only experiment cost through
chat, compare again and retain a second review; all other settings and the first
review remain unchanged. Exercise stale model and concurrent manual-edit cases.

**Scope boundary:** Reuse and presentation of implemented BED, without widening
its statistical family, utility contract or execution authority.


<a id="sup-038"></a>

### SUP-038 — Explore the world implied by a model

**Outcome:** A user starts with a provided or user-supplied brms model, understands
its conditional consequences, and retains a qualified interpretation and a
concrete proposed challenge.

**Priority:** P1 · **Milestone:** M3 · **Status:** implemented

**Acceptance criteria**

- [x] Provide a bounded brms adapter with explicit scenarios, units, scientific
  context, supported likelihoods, computation failures and run provenance.
- [x] Ship genuine brms prediction snapshots and reproducible fitting code for
  straight-line and curved coating models and a positive, skewed waiting model;
  exploration requires no provider, brms installation or Stan compilation.
- [x] Link coherent parameter draws, simulated outcomes, conditional contrasts,
  meaningful thresholds and comparisons on a compatible scenario grid.
- [x] Distinguish structural restrictions, author-supplied scientific context,
  computed implications, fitting-range extrapolation and actual evidence.
- [x] Retain independently worded claims, reviewer positions and proposed
  challenges with exact source snapshots and reviewed settings; changing the
  model or wording invalidates review.
- [x] Reopen portable and native-history records without losing models or
  reviews, replaying actions or importing acceptance into a new draft.
- [x] Keep examples and drafts isolated across sessions and verify desktop,
  mobile, keyboard controls and accessible figure descriptions.

**Implementation evidence:** [Model-world acceptance](../../artifacts/model-world-review.md)
and the executable [model-world guide](../../vignettes/model-worlds.Rmd).

**Verification:** Compare the snapshots directly with brms and independently
reconstruct expected responses from coefficient draws; verify actual browser
review/export/reopen records, focused tests, package checks and evaluated docs.

**Scope boundary:** Initial univariate Gaussian and lognormal MCMC models with
ordinary numeric terms, no group-level effects or special prediction contracts.
Model snapshots are simulations. Retaining an interpretation neither adds
observations nor freezes a prospective test. No automatic external-model refit,
general sensitivity or experiment-design calculation; no Stan or tidymodels
adapter yet. Intended-scientist acceptance in SUP-011 remains separate.
