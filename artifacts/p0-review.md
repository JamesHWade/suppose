# P0 implementation and acceptance evidence

September 8, 2026. All scientific examples below are invented test cases. Browser
operations were performed by the agent, not an intended scientist or engineer.

## Completed behavior

| Item | Result | Evidence |
|---|---|---|
| SUP-003 | Independent claims can reference several retained candidate priors; several claims can reference one prior. References retain their author and rationale without changing fitting or acceptance. | `test-model-reference.R`, `test-inquiry-app.R`; saved browser relationship |
| SUP-004 | Manual review captures ranges, explicit quantiles, two-condition comparisons and shape regions. Original wording, units, attribution, rationale, sources and prior information remain available. Additional answers coexist with fitting inputs. | `test-judgment-app.R`, `p0-browser.txt`, `p0-browser-record.json` |
| SUP-007 | Explicitly chosen straight-line projections distinguish anchors, interpolation and extrapolation. Mean uncertainty and future-batch variation are separate. The UI compares quantiles and exposes the straight-line model's inability to express an interior peak. | `test-expectation-check.R`, `p0-browser.txt`, `p0-numeric-browser.txt` |
| SUP-009 | Keyboard review/acceptance, a labeled native correlation input, nonvisual plot descriptions, 390px layouts and native browser file upload/download work. Upload success/errors appear next to the control in the narrow drawer. | `p0-browser.txt`, `p0-numeric-browser.txt`, mobile screenshots |
| SUP-010 | Actual Deputy/shinychat streaming supports decline, cancellation, retry and human correction. Model-access failure leaves a usable manual editor. | `p0-recovery-browser.txt`, `p0-streaming-browser.txt`, saved records |
| SUP-011 | Reproducible synthetic acceptance, R/CLI verification and documentation are complete. Intended-user validation remains open. | Reports and commands below |

These are bounded features for the implemented normal-prior workflow. Claim/prior
references do not claim support for arbitrary external models. A new projection
assumption is not attributed to the original two elicited answers. Matching an
answer is not empirical evidence or a model-adequacy score.

## Browser acceptance

The current numerical form was exercised without credentials. Keyboard changes
to correlation from 0.8 to 0 changed the displayed probability of a mean gain
above 5 MPa from 87.8% to 71.7%, holding the marginal intervals fixed. Changing
inputs blocked acceptance until reinspection. A reversed quantile pair produced
a clarification; correcting it restored computation. Explicit acceptance retained
a reason and a proposed randomized-batch challenge, then survived native download
and upload in a fresh session.

The conversation workbench separately retained a comparison with no assigned
probability, an interior-peak expectation, an uncalibrated plausible range and
contradictory quantiles. Impossible probability levels were rejected. The
projection view retained the original answers and explained its shape limitation.
A separately worded claim was linked to a retained prior. Browser download/upload
preserved all earlier revisions and acceptance, candidate IDs, judgments and the
relationship exactly under the package's canonical JSON representation.

The scripted model uses a real local OpenAI-compatible streaming endpoint, Deputy
and shinychat. Decline left one initial draft. Applying a fresh proposal made two
revisions. Cancellation preserved those two revisions exactly; retry and explicit
application made three. Human correction made four, retaining the exact original
suggestion and correction reason. A separate app pointed at an unavailable local
endpoint demonstrated manual clarification and download after model failure.
These fixtures test integration and recovery; they do not assess an LLM's
scientific judgment. Earlier live-model semantic evidence remains in
`QUALITY-REVIEW.md`.

## Defects found and repaired

- Additional judgments were discarded when `record_revision()` received a fitted
  candidate. Fitting inputs and additional judgments now coexist without duplicate IDs.
- Browser verification caught unbound projection/relationship modules; a full-host
  test now exercises their outputs and relationship retention.
- A reused cancelled shinychat controller stopped the next Deputy run before
  ellmer's usual reset. The adapter resets it after Deputy accepts a new lazy
  stream; rejected concurrent calls preserve the existing cancellation.
- The numerical correlation slider exposed a readonly, nonfocusable input. The
  form now uses a labeled native numeric control, verified with Tab and arrow keys.
- Upload feedback was hidden in the chat footer when the narrow record drawer was
  open. Feedback now also appears beside the upload control, including invalid-file errors.

## Verification

- Final installed-package suite: 1,280 assertions, zero failures, warnings or skips.
- All three browser scripts pass; the numeric and conversation layouts have no
  page-level horizontal overflow at 390 × 844. The wide prediction table is a
  labeled, focusable scrolling region.
- `p0-record-verification.log` verifies the persisted consequences, rather than
  inferring success from visible clicks.
- `p0-cli-verification.log` verifies the isolated ir launcher: numerical results,
  qualitative meaning, paths with spaces, stdout/stderr separation, overwrite
  refusal, required seed and unavailable numerical predictions.
- Package documentation builds with pkgdown; new topics are in the reference index.
- Air formatting and focused Jarl checks pass. Jarl excludes unused-function
  detection when checking only the new files; the host integration tests cover
  their registration and execution.
- Final `R CMD check`: zero errors, warnings or notes; see `p0-final-check.log`.

### Reproduce

Use the compatible development dependencies described in `README.md`. From the
package root, start each fixture in its own terminal:

```sh
Rscript dev/run-p0-app.R example 3905
python3 dev/inquiry-fixture-server.py 3907
Rscript dev/run-p0-app.R fixture 3906
Rscript dev/run-p0-app.R unavailable 3908
Rscript dev/run-p0-app.R numeric 3909
```

With Playwright available to Node and installed Chrome:

```sh
node dev/verify-p0-browser.cjs
node dev/verify-p0-recovery.cjs
node dev/verify-p0-numeric.cjs
Rscript dev/verify-p0-records.R
```

`p0-desktop.png`, `p0-mobile.png`, `p0-numeric-mobile.png` and
`p0-unavailable-mobile.png` retain visible layout evidence. The test fixtures use
isolated sessions and no paid model.

## Still open

SUP-011 requires an intended scientist or engineer to recognize the formalization,
identify a consequential assumption and propose a challenge. No such walkthrough
has occurred. This remains the P0 validation gate.

The checks are not a full WCAG audit, screen-reader certification, cross-platform
qualification or field calibration study. Screen-reader behavior and operating
systems other than this macOS/Chrome environment remain unverified. External
model adapters and richer regression projection/claim relationships remain later
backlog work.
