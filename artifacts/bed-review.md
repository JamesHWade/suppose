# Exact BED implementation and acceptance

Verified September 8, 2026. This implements exact one-step Bayesian experimental
design for the existing normal/inverse-gamma regression, motivated by Action-BED's
focus on downstream loss. It does not reproduce its learned design/action policies.

## Delivered

- [alloptr numerical engine](/Users/james/notes/alloptr/R/bed-normal.R): exact
  expected posterior contrast-variance reduction and expected two-action
  opportunity-loss reduction, integrating unknown common noise and independent
  replication. Candidate rows are separate alternative experiments.
- [Suppose adapter](../R/research-design.R): retained-model and predictor-unit
  references, two target settings, explicit criterion/preference, total experiment
  cost in compatible loss units, feasibility, unit budget, ties and no-benefit
  outcome. Model checks remain visible. The chosen protocol's utility penalty is
  distinct from the cost of collecting measurements.
- [Chat and review](../R/research-design-forms.R): draft_research_design prepares
  /design, protects manual edits and stale record state, and preserves source
  context. Human review retains a planning choice, including none. Schema 11
  records preserve scientific evidence and earlier models unchanged.

## Independent numerical evidence

Alloptr's 18 focused assertions passed. Expected decision benefit agrees with
independent predictive Student-t quadrature; variance reduction agrees with a full
matrix precision update. Other checks cover replication, zero information, utility
thresholds, unit rescaling and invalid covariance/replicate inputs. The
[source review](bed-implementation-evidence.md) includes derivations and an
independent joint NIG simulation. Core scoring uses no Monte Carlo approximation.

For a fixed contrast and zero experiment costs, the two supported criteria can
rank candidates identically. Changing the purpose does not necessarily change the
best setting. Different targets, costs and richer losses can change that decision.

## Actual chat and persisted-state acceptance

Continued the fictional 18-row coating example in conversation
`c_001a0837680ce1d896ca15e`. The retained extended model compares temperature and
drying time; its largest-residual check remains borderline (tail area 0.975).

The new request explicitly supplied feasible alternatives, independent batches,
a six-unit budget, zero experiment cost, and an illustrative linear utility
threshold of 15 cycles. It explicitly left real energy economics unresolved.
The target was protocol B (70 C / 30 minutes) minus A (50 C / 30 minutes).

| Alternative | Independent batches | Expected decision benefit (cycle-equivalents) |
|---|---:|---:|
| 50 C / 30 minutes | 1 | 0.04590956 |
| 50 C / 30 minutes | 6 | 0.27985524 |
| 70 C / 30 minutes | 1 | 0.04590956 |
| 70 C / 30 minutes | 6 | 0.27985524 |

Current expected opportunity loss was about 0.8248 cycle-equivalents. The two
six-batch alternatives tied. Chat correctly described the scores, provisional
preference, unresolved economics and model check. It did not invent new data.

The human review selected T50x6 with an explicit reason. The saved JSON contains
one planning review, both original regression reviews, the original observations
and predictors, and the R analysis. No prospective commitment or execution was
created. Native reopening preserved the planning entry exactly.

Reproduce the numerical and preservation checks with:

```sh
Rscript dev/verify-bed-history.R
```

[Acceptance output](bed-acceptance.log), [saved record](bed-conversation.json),
[reopened record](bed-reopened-conversation.json).

The live test exposed two wiring errors (the new tool was absent from the
permission allowlist, and the host guard called a nonexistent function). Both
were fixed. New tests exercise all advertised core-tool permissions and the full
inquiry host's planning-retention path. The successful retry and restoration
occurred after those fixes. The latest host-focused run passed 75 assertions.

## Package verification and limits

- Suppose R CMD check: **0 errors, 0 warnings, 0 notes**.
  [Full log](bed-final-check.log).
- Alloptr R CMD check: **0 errors, 0 warnings, 0 notes**.
  [Full log](bed-alloptr-check-final.log).
- Alloptr's optional modeling/provider tests skip when dependencies are absent.
  The first broad run exposed an existing published-study fixture that used
  recipes without a skip guard. Guards now explicitly cover that fixture's
  recipes/parsnip/workflows requirements. No packages were installed to mask this
  limitation; absent optional paths are not claimed as verified.
- Air formatting and Jarl checks passed. The Suppose documentation site built.
  `pkgdown::check_pkgdown()` additionally requires a public `url` configuration,
  which this local project does not yet have; no hosting URL was invented.
- External system-clock lookup was disabled for R CMD check; package checks and
  tests remained enabled.

The engine scores finite, user-supplied single-setting alternatives. A retained
planning choice is not an alloptr campaign proposal or prospective experiment.
Campaign dispatch, multi-setting batches, regression-specific commitments and
sensitivity, richer reference models, nonlinear utilities and learned policies
have separate backlog items. The current form does not automatically repopulate
all controls from a retained review on reopening; the saved review remains
inspectable and chat can prepare a revised draft. Model assumptions, especially
independence, normality, observational confounding and common noise, still limit
the interpretation of every design score.
