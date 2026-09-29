# First-session quality: implementation and adversarial review

September 7, 2026. This increment follows the failures in [WALKTHROUGH.md](../../WALKTHROUGH.md).
The updated app is available at http://127.0.0.1:3896/. Existing conversations on
ports 3891 and 3895 were preserved. No repository, PR, or deployment was created.

## Delivered behavior

- The assistant offers concrete observable possibilities when a person cannot
  define an outcome, and keeps epistemic distinctions mostly in the record.
- Proposed expectations and assumptions retain complete user quotations and
  their full source context. Questions and truncated statements are rejected.
  Assistant explanations, candidate assumptions, and next steps have a separate
  “ideas to consider” section; applying a draft does not adopt them.
- Missing scalar fields are retained as unknown. Units must occur as unit tokens
  in a user message; letters inside ordinary words do not establish units.
- **Correct suggestion** opens a prefilled form. Applying a correction keeps the
  exact assistant proposal and the reviewer's changes/rationale in history.
  It creates an unaccepted revision and clears proposed numerical results.
- A pending suggestion must be applied, corrected, or declined before semantic
  acceptance. Retained and proposed interpretations are labeled separately.
- Discussion without a new proposal leaves the pending proposal's identity
  unchanged. Cancellation restores the previous proposal. A tool-only response
  can be saved without inserting an invalid empty conversation message.
- CLI inspection now includes qualitative meaning and review state. A prediction
  request explains when a record has no numerical candidate.

## Adversarial findings addressed

| Finding | Failure mode | Resolution and evidence |
|---|---|---|
| Conditional question becomes expectation | “If three teams say yes…” lost its condition in the proposed record. | Full-statement quotation boundaries reject extraction and question-to-statement conversion. The live demand correction retained the complete negative expectation and the original conditional open question. |
| Assistant assumption becomes user commitment | Suggested explanations occupied the user's assumptions field. | User assumptions require source statements; assistant ideas remain separate in the proposal and retained proposal history. Human correction remains explicit. |
| Decimal punctuation defeats quotation boundaries | A decimal point could be mistaken for the end of a sentence, allowing a shortened quotation. | Boundary checks require appropriate spacing; adversarial decimal cases reject both prefix and suffix truncation. |
| Inferred units from ordinary letters | A substring check could find “s” inside “results.” | Unit-token boundaries reject that interpretation while accepting units attached to values, such as `5mV`. |
| Invalid tool input partially changes a draft | Validation after staging could leave a malformed attempted correction behind. | Validate fields, sources, and reason before staging. Tests assert unchanged state after rejection. Nested arrays and numeric list entries are not silently coerced to text. |
| Reviewer accepts the wrong displayed state | A proposed interpretation could appear above the retained revision's acceptance controls. | Both UI and server guard acceptance while a suggestion is pending. A server test verifies no acceptance is recorded. |
| Human correction inherits incompatible results | Rewording a proposed claim could keep its old numerical conclusions. | Corrected application clears candidate, prediction, judgments, and threshold, preserving earlier revisions and the exact original proposal. Round-trip tests verify provenance. |
| A stale correction form applies an old suggestion | Conversation, decline, or other edits can invalidate an open form. | The form is bound to the proposal ID and the proposal to the source record; stale correction and duplicate application tests reject the action. |
| Discussion manufactures a new proposal identity | Finishing an ordinary explanatory response recompiled the pending suggestion. | No new proposal tool or preview means the exact existing proposal is retained. |
| Empty assistant response breaks persistence | A successful tool-only response could add an empty message rejected by bundle validation. | Preserve the proposal and tool receipts without an empty textual message; save/reopen is tested. |
| CLI hides qualitative records | `inspect --json` showed counts and numerical results but omitted the actual question. | Both human and JSON inspection include the interpretation; isolated CLI verification compares it with a saved live record. |

These changes were reviewed against the baseline source and exercised with
malformed inputs, stale state, cancellation, model output, and persisted records.
The initial R/test/development-script snapshot is retained in
`artifacts/quality-baseline.tar.gz` for later comparison.
No unresolved blocking defect was found in the bounded implementation after the
fixes. This is not a claim that every generated interpretation is correct.

## Live evaluation and what failed during development

`dev/live-quality.R` runs explicitly fictional coordination, demand, and research
examples through the real Muse/Deputy path. Each has two conversational turns.

The first pass produced useful concrete help but exposed three additional
problems: empty strings for unknown fields, unsuccessful quotation attempts in
the research case, and a browser response claiming a draft existed without a
proposal call. The first-pass log and completed records are preserved under
`artifacts/quality-pass1/`; that pass was **not** treated as successful validation.

After correction, all three two-turn cases produced proposals and completed JSON
round trips. The demand case initially attempted a truncated negative statement;
the tool rejected it with source context, and the model repaired it to:

> Still within this fictional example: I do not expect three teams to buy.

The conditional interview question stayed unresolved. No numerical model was
attached to any of the three records. The research record retained variation
between repeated runs rather than a higher mean; units and effect size remained
open. The coordination case retained a possible two-week trial and unchanged
individual check-ins, rather than recording a commitment or completed experiment.

Evidence: `artifacts/quality-live.log`, `artifacts/quality-live-*-trace.json`, and
`artifacts/quality-live-{coordination,demand,measurement}.json`. Harness application
of those fictional proposals was for persistence verification, not human semantic
acceptance or evidence about a real organization or market.

A separate browser session verified direct correction, keyboard traversal with
visible focus, scrolling with fixed action buttons, explicit semantic acceptance,
and inspection of the original suggestion and correction rationale in history.
Another live session cancelled an active response, retried successfully, and
declined the proposal; history still contained exactly one unaccepted revision.
The retry also repaired a rejected quotation. It exposed verbose unknown-field
placeholders, which the final scalar normalization and unit tests now cover.

## Verification

- **52 tests, 307 passing expectations**, no failures, warnings, errors, or skips
  in the complete local suite. `artifacts/quality-test-counts.json` and
  `artifacts/quality-full-tests.log` contain the results.
- **R CMD check: 0 errors, 0 warnings, 0 notes**. Snapshot tests were enabled with
  `NOT_CRAN=true`; remote clock verification was disabled.
  See `artifacts/quality-check.log`.
- Air formatting and generated roxygen help checked. The local pkgdown site is
  rebuilt; its standalone metadata check still reports the pre-existing missing
  canonical URL because no hosted site exists. No URL was invented to hide it.
- Official ir 0.4.0 installed the current package into a fresh temporary library.
  Both `rx --from local::... suppose --help` and the installed launcher worked.
  `dev/verify-cli.R` checks numerical agreement, qualitative meaning, paths with
  spaces, clean stdout/stderr, overwrite refusal, missing seed, and absent model.
  User profile/environment files are disabled, and the launcher sets
  `R_LIBS_USER=NULL`. See `artifacts/quality-cli-verification.txt`.

## Remaining limits and next work

Quotation checks establish textual support, not truth or a general semantic
classification. They use conservative punctuation rules and may require a longer
quotation or manual correction. A model can still misclassify a complete statement
or overstate a paraphrased headline. Source context, original wording, and explicit
review remain necessary. Tool validation can require an additional model round
trip; the successful live tests are a small sample, not a reliability estimate.

The assistant is instructed to claim a draft action only after a successful tool
call. The app's status reflects actual state even when prose does not. The later
live pass matched its action claims to actual proposals, but this is not a
guarantee about all future model responses or other selectable models.

Intended-user acceptance, a full small-screen/screen-reader audit, and portable
installation of the development UI stack remain open. These tests did not repeat
a native browser file-upload round trip; server and fresh-process persistence
checks cover that data path. Observations, posterior updates, and prospective
assessment (SUP-012 onward) remain separate future work.
