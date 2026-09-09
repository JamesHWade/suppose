# Evidence for a tractable task-driven BED slice

**Implementation decision:** the exact scorer is now implemented in
[alloptr::bed_normal_contrast()](/Users/james/notes/alloptr/R/bed-normal.R).
Suppose adapts a retained model and presents a planning review through
[design_regression()](../R/research-design.R). The campaign-dispatch adapter remains
SUP-020. [Verification and remaining limits](bed-review.md).

Checked 2026-09-08. This document separates verified research, a derivation for Suppose's current model, and recommended product scope. It is not a claim that Action-BED's learned policies or an alloptr campaign adapter are implemented.

## Research anchor

[Action-BED, Rossa, Phillips and Rainforth, arXiv v1, submitted 22 June 2026](https://arxiv.org/html/2606.23662v1) formulates experimental design through expected future loss on downstream actions. Section 3 connects variance reduction to squared-error estimation. Section 4 jointly trains neural design and action policies using simulated trajectories and stochastic gradients; its posterior-free computational strategy is distinct from exact conjugate updating. Appendix G says code is public, but the inspected HTML does not supply a repository link; searches by title and authors did not establish an official code location. This is a preprint, and its benchmarks do not establish performance for Suppose's regression workflow. The useful immediate adoption is explicit task/loss specification; deploying its policy-training machinery is a separate research project.

## Inspected implementation and ownership

[Suppose regression](../R/regression.R) has a proper normal/inverse-gamma (NIG) posterior, fixed predictor transforms, and one or two numeric predictors. It models independent normal observations with a shared unknown variance. Current retained fits contain the mean vector, conditional covariance factor, shape and rate required below. The calculations concern the model's conditional consequences, not causal identification or empirical calibration.

[CONCEPT.md](../CONCEPT.md) and [SUP-020](../BACKLOG.md#sup-020) allocate campaigns and numerical design to alloptr. The inspected [alloptr README](/Users/james/notes/alloptr/README.md) separates proposals, acceptance, executed runs, observations and budget; its current modeling layer is not a BED dispatch backend. Do not reproduce those ledgers in Suppose.

A small exact posterior-consequence **preview** can sit next to regression inference in Suppose if its narrow scope is explicit: score user-supplied candidate settings, never allocate campaign budget or authorize execution. Record this boundary as an intentional refinement of SUP-020; general candidate search, feasibility, batches, and campaign scheduling remain alloptr responsibilities. Keep the numerical scorer pure, with a versioned input/output contract that an eventual adapter can consume or move upstream. If numerical-design ownership is interpreted strictly, put that scorer in alloptr instead; do not quietly imply a completed alloptr integration either way.

## Derivation for replicated single-setting designs

The following is our derivation from the inspected NIG model, not an algorithm claimed by Action-BED. Write the current posterior as

- `sigma² ~ IG(a, b)`, with rate convention and `a > 1`;
- `beta | sigma² ~ Normal(m, sigma² V)`;
- a candidate has transformed row vector `x` and `n` independent, exchangeable replicates with the same noise variance.

Let `h = 1/n + x' V x`. Its sample mean has marginal distribution

`ybar ~ t(df = 2a, location = x'm, scale = sqrt((b/a) h))`.

After those observations, the coefficient posterior mean obeys

`m_new = m + Vx / sqrt(h) * sqrt(b/a) * T`, with `T ~ t(2a)`.

For a target `c'beta`, the current minimum squared-error loss is its posterior variance, `(b/(a−1)) c'Vc`. The exact expected reduction is

`gain = (b/(a−1)) (c'Vx)^2 / h`.

This follows from the law of total variance. Although the realized posterior variance depends on future responses, its expected reduction is determined by the design. No predictive Monte Carlo or learned action model is needed. Variance reduction has squared target units; it is not entropy reduction and should not be labeled generic information gain.

For finite actions with reviewed linear utility `u_j(beta) = d_j'beta − p_j`, where `p_j` is a fixed penalty in the same utility units, the Bayes action maximizes posterior expected utility. Define

`alpha_j = d_j'm − p_j`, and `gamma_j = d_j'Vx / sqrt(h) * sqrt(b/a)`.

Then

`EVSI = E_T[max_j(alpha_j + gamma_j T)] − max_j(alpha_j)`.

Each pair of affine functions crosses at most once. Sort finite crossing points, identify the winning line on each interval, and integrate it using the Student-t CDF and truncated first moment. For an interval `(l,u)`,

`E[T 1(l<T<u)] = M(l) − M(u)`,

where `M(t) = ((nu+t²)/(nu−1)) dt(t,nu)`, `nu=2a`, and `M(−Inf)=M(Inf)=0`.

Handle equal slopes, duplicate actions, ties and infinite endpoints explicitly. Use numerically stable tail probabilities and moments for distant crossings; avoid overflow in `t²` multiplied by a vanishing density. A nonnegative exact EVSI may become tiny negative through floating point; tolerate only roundoff, not substantive negative values.

Two-action oracle: for advantage `Z = mu + s*T`,

`E[max(0,Z)] = mu*pt(mu/s,nu) + s*((nu+(mu/s)^2)/(nu−1))*dt(mu/s,nu)`.

Subtract `max(0,mu)` for EVSI, and use zero when `s=0`. An independent quadrature spot check (`nu=8`, `mu=−0.7`, `s=1.2`) gave `0.2568748` for expected positive utility, matching the closed form within `2.3e−13`. A separate 300,000-draw joint NIG simulation of a contrast gave exact gain `0.5233846` versus simulated variance of the updated target mean `0.5244050`. These checks support the derivation; they do not replace implementation tests.

For `n` replicates the variance shape update is `a+n/2`, not `a+1/2`. Treating the average as a single observation loses residual information about noise. The formulas above remain valid for these two objectives because linear action utility depends on the updated mean, and target expected variance uses the tower property. They do not justify approximating full posterior updates by an average for arbitrary losses.

## Concrete acceptance recommendations

1. **Bounded posterior preview.** Require a retained fit/model choice, attributable objective, target or explicit action table, penalties with units, candidate settings, positive integer replication counts and candidate identifiers. Preserve model/record identity, transforms, assumptions, method version and warnings. Reject missing predictors, non-finite or invalid inputs. Label extrapolation and conditional scope. Show every alternative and the no-new-experiment baseline.
2. **Evidence-based numerical tests.** Compare envelope calculations with independent numerical quadrature, include the two-action oracle, identical/dominated actions, equal slopes, utility translation invariance, positive utility rescaling, permutation invariance, zero contrast, increasing replication, symmetry and near-degenerate covariance. Verify target variance reduction against a rank-one covariance update and predictive simulation. Confirm changing the target or action penalties can change rankings.
3. **Reviewable decisions and costs.** Distinguish downstream protocol penalties from experiment costs. Subtract experiment cost only in compatible utility units; otherwise use separate constraints. Keep negative net benefit and a do-not-experiment option visible. Variance scores cannot be compared numerically to decision utility. A cost in dollars cannot be silently subtracted from cycles or cycles squared.
4. **Campaign adapter.** Before calling this SUP-020 complete, connect to alloptr's public proposal/acceptance/execution/observation contracts, enforce feasibility and budget there, preserve planned versus actual settings and stable IDs, reject stale proposals, and test save/reopen plus assessment against frozen predictions. No accepting a preview as an executed or funded campaign.
5. **Full batches and richer tasks.** A repeated single setting is not a general batch optimizer. Implement joint batches and search in alloptr, compare exact enumeration on small grids, and label greedy search if used. Threshold error, reliability, nonlinear loss, model discrimination, heteroscedasticity and model averaging require separate supported calculations. They are not represented by linear expected utility.
6. **Scientific model revision.** Preserve unresolved checks when suggesting measurements. Add hierarchical interactions and reviewable transforms, unit/domain checks and predictive comparisons before using them for design. Later external-model adapters must expose joint posterior predictive draws, noise assumptions, stable model identity and supported losses. Model-dependent design does not validate the model it assumes.
7. **Action-BED evaluation, later.** Gate learned policies on a repeated-campaign use case, verified official implementation/license or an explicit independent reproduction, differentiable simulator/loss capability, held-out simulated rollouts and comparison with exact finite-design oracles. Measure training cost, action approximation error and decision regret; do not infer production readiness from published benchmarks.

For future Monte Carlo methods, preserve joint coefficient/variance draws and joint batch outcomes; marginal interval sampling is invalid. Avoid minimizing noisy inner risk estimates on the same draws used to evaluate the selected action, which makes estimated loss optimistic. Prefer analytic posterior action risks when available. Report simulation count, seed, Monte Carlo error and close-ranking uncertainty, and independently re-evaluate selected candidates to expose selection optimism. These are numerical acceptance recommendations, not additional claims about the paper.
