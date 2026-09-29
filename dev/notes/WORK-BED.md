# Exact Bayesian experimental design and research backlog

Authorized 2026-09-08: implement tractable BED and shape the next steps with evidence.

- [x] Verify Action-BED and choose an honestly bounded computational method.
- [x] Implement exact normal/inverse-gamma contrast and two-action design scoring in alloptr, with independent numerical oracles.
- [x] Adapt retained Suppose regressions to reviewed candidate settings, independent replication, explicit loss/cost units and model checks.
- [x] Expose chat-prepared design reviews, preserve proposals and human decisions, and verify restoration.
- [x] Populate stable backlog items for campaign integration, prospective regression tests, scientific features, reference models and learned design policies.
- [x] Run package and browser acceptance checks and document evidence and limitations.

## Bounded method

Finite candidate settings, each with an explicitly reviewed number of independent
replicates. Exact expected posterior variance reduction for a mean contrast,
or exact expected reduction in opportunity loss when choosing between two
protocols with a stated outcome-equivalent indifference threshold. Unknown common
noise is integrated out. This implements decision-focused BED without Action-BED's
learned design/action policies. alloptr owns the numerical method; Suppose owns
model adaptation, scientific provenance, and review. A saved design review is
not a campaign execution or a frozen prospective test.

Evidence: artifacts/bed-implementation-evidence.md (research in progress).

Completed: both R CMD checks pass with 0 errors, 0 warnings and 0 notes.
Alloptr optional-provider tests skip when their declared dependencies are absent.
A pre-existing published-study test needed explicit optional-package guards;
no missing package was installed. Actual chat, pending-draft restoration, human
retention, exact saved-score recomputation and native reopening were verified.
See artifacts/bed-review.md.
