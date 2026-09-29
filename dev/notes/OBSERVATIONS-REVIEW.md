# Observation import: implementation and critical review

September 8, 2026. Implements the bounded SUP-012 path: CSV/data-frame import,
explicit provenance and exposure, reviewed attachment, JSON persistence, and R,
CLI, and Shiny inspection. This is a self-review against the saved baseline in
`/private/tmp/suppose-observation-baseline`, not an independent reviewer verdict.

## Delivered behavior

- Original outcomes, missing values, stable measurement identities, conditions,
  batches, specimens, protocol, source, contributor, and UTC observation times.
- Explicit affine conversion retains originals and records scale, offset, and
  destination units. Attachment checks those units against the exact claim.
- Exact repeated measurement fields are flagged and retained. Duplicate IDs in
  one source are rejected; attaching those source/IDs again, including under a
  new role or conversion, is rejected.
- Exposure is explicit. Previously explored or uncertain outcomes cannot be
  labeled for assessment. Outcomes already incorporated into a prior, or with
  unknown exposure, cannot be designated for updating.
- Attachments refer to a specific record entry, claim, and candidate. Accepted
  revisions are unchanged; later revisions do not relabel earlier evidence.
- Schema 4 retains measurements separately from judgments and simulated
  predictions, while continuing to read schemas 1–3.
- The record drawer previews data and provenance before explicit attachment.
  Changed inputs, changed records, active model responses, and pending assistant
  suggestions block stale or ambiguous attachment. Save/reopen retains evidence.
- The CLI `observe` command saves a new bundle; `inspect` includes the evidence.
  The assistant receives attachment summaries with revision and exposure; it
  does not receive measurement rows through this summary tool.

## Findings and fixes

| Finding | Resolution and evidence |
|---|---|
| Missing outcome could lose its converted field when represented by NULL | Store the field explicitly; tests cover missingness and complete JSON round trips. |
| Schema-3 conversation/acceptance operations could downgrade a measurement bundle | Preserve the greater schema version; tests attach, accept, save conversation, and reopen. |
| A resealed object could carry outcomes inconsistent with its conversion | Revalidate rows and derived fields against original values and conversion before attachment/read. A malformed-record regression verifies rejection. |
| Same measurements could be counted twice under a new purpose | Validate source/ID uniqueness across the whole evidence collection. Browser and CLI attempts fail without adding a second attachment. |
| A displayed preview could be attached after changing metadata or the claim | Compare the preview's original inputs and record content ID before attachment; server tests cover both paths. |
| CLI argument help containing an unquoted colon broke Rapp's YAML parsing | Changed the help text; complete CLI tests and an isolated launcher pass. |
| ellmer 0.5 deprecated raw-list tool results | Return explicit JSON to the model while retaining structured internal receipts; transport and numerical-preview tests cover both forms. |
| Preview without a CSV produced an empty status | Browser discovery: replace silent Shiny `req()` handling with an actionable error; retain a regression test. |

## Verification

- Full suite: 362 passing expectations, no failures or skips.
- R CMD check: 0 errors, 0 warnings, 0 notes. Remote system-clock verification
  disabled. Logs: `artifacts/observations-final-check.log`.
- Browser: live Muse proposed a fictional warm/cold-voltage interpretation.
  Its first quotation failed validation; it repaired that call successfully.
  A synthetic CSV uploaded through the real file chooser, previewed three rows
  (one missing, two flagged as repeated), attached to revision 2, and refused
  duplicate import. Browser download reopened in a fresh R process with the
  original rows, metadata, reference, and conversation preserved. Evidence:
  `artifacts/observations-browser-record.json` and `observations-fixture.csv`.
- At 390 × 844, page width remains 390 and the record drawer fits at 366 pixels.
  The screenshot `artifacts/observations-mobile-preview.png` was inspected.
  Table overflow is contained inside the table wrapper. Inputs have labels,
  table headers have scope, and status text has a polite live region.
- Installation: public Shinychat commit
  `eb024589465f5227405d567854b96cc87e5bb9ac` builds from `pkg-r`; 201 focused
  inquiry/module expectations passed against that build. A fresh ir library
  installed 51 packages, including this public Shinychat, Deputy
  `4a8ee639df8c5e5e32567cb706b722f14732c923`, and ellmer 0.5.0. The installed CLI
  passed its numerical/qualitative checks; isolated UI/Agent constructors and a
  real Muse call succeeded. A full browser stream and tool call also worked against the isolated stack.
  This verification used macOS and R 4.6.

After attachment, a second live response read the attachment summary, correctly
reported the counts and exposure, said no posterior or independent test had been
performed, and made no new proposal. The summary field for potential duplicates
was then clarified to avoid implying that matching fields prove accidental
copies. `artifacts/observations-summary-reply.md` retains the observed response.

## Remaining limits

Exposure and source identity are contributor declarations, not authenticated
proof. Renaming the same source can defeat identity matching. Distinct datasets
may contain related or dependent measurements that exact-ID checks cannot find.
Duplicate-field flags do not establish that two measurements are accidental
copies. Conversion correctness requires scientific review. Protocol descriptions
and batch/specimen IDs are retained, not used to infer an experimental design.

The importer intentionally has no overwrite/reclassification operation: errors
in an attached dataset require starting from the earlier saved record. A future
revision API must preserve both versions and expose the correction explicitly.
There is no posterior fitting, independence certification, prospective commitment,
or statistical assessment in this increment (SUP-013/SUP-014 remain open).

The live model still assigned "Fictional measurement walkthrough" as a time
horizon, which is not a temporal horizon. Source matching is not semantic
validation; the suggestion remained reviewable. Broader model quality and
intended-user acceptance remain open. The small-screen check does not substitute
for a screen-reader audit or testing other operating systems.
