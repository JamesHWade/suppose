# Using a fitted model to choose better research

Research checked 2026-09-08. This is a product and methods recommendation, not an implemented integration or an exhaustive literature review. Publication years below come from the sources, not search-engine relative dates.

Suppose can turn a fitted model into a guide for what to measure next. The useful question is: **which feasible observation would most improve the particular scientific conclusion or decision we care about?** A model can support several different answers. Improving the response, learning a mechanism, and detecting that the model is wrong need different objectives.

## What the repositories already provide

Suppose already anticipates this in [SUP-020](../dev/notes/BACKLOG.md#sup-020): estimation, discrimination, inadequacy detection, or outcome improvement, with explicit cost, noise, replication and feasibility. [SUP-019](../dev/notes/BACKLOG.md#sup-019) concerns decisions and value of information. The current [regression implementation](../R/regression.R) supplies exact normal/inverse-gamma inference for one or two numeric predictors, unknown common variance, predictive checks and exploratory comparison. It does not yet support interactions, general samplers, or regression-specific prospective commitments. [Current scope](../dev/notes/BACKLOG.md#sup-028).

The inspected [alloptr README](/Users/james/notes/alloptr/README.md) and [BO implementation](/Users/james/notes/alloptr/R/bo.R) provide campaign spaces, feasibility, budgets, distinct proposal/acceptance/execution/observation ledgers, stale-state checks, replication and a native GP expected-improvement baseline. The optional BoTorch route has a narrower continuous unconstrained contract. Its [modeling layer](/Users/james/notes/alloptr/R/modeling.R) supports recipes fitted within resamples and explicit uncertainty adapters, but its README explicitly says that layer is not yet a BO dispatch backend. **A fitted Suppose posterior cannot currently be plugged into a ready-made alloptr information-gain method.** That requires a new bounded adapter and numerical capability.

Keep the existing ownership: Suppose records what a claim means, why a measurement matters, the model revision, and how evidence bears on the claim; alloptr owns campaign state and numerical design. The chat host presents drafts and approvals. This follows the current [Suppose concept](../CONCEPT.md).

## Four useful objectives

| Purpose | Coating example | Appropriate ranking |
|---|---|---|
| Improve an outcome | Find temperature and cure time with better expected abrasion life | Bayesian optimization, with a stated outcome objective |
| Estimate something | Learn the change in abrasion life from a meaningful temperature increase | Expected reduction in uncertainty of that effect or a target prediction |
| Distinguish explanations | Additive temperature/time effects versus temperature-dependent cure-time effect | Expected information about the model, using full noisy predictive distributions |
| Improve a decision | Choose a faster protocol while accounting for unacceptable abrasion life | Expected reduction in decision loss after a proposed experiment, less its cost |

Bayesian experimental design evaluates possible future observations under the current model, then averages their learning or decision benefit before outcomes are known. Parameter information gain is one criterion; targeted quantities, model discrimination and downstream utility are different choices. This is established Bayesian decision theory. The 2024 synthesis also covers discrete candidate selection and adaptive policies. [Huan, Jagalur and Marzouk, 2024](https://www.cambridge.org/core/journals/acta-numerica/article/optimal-experimental-design-formulations-and-computations/38BBD0DC1A0386FDF306B6C0167DF7D9).

For decision loss L and a future batch outcome y, a natural proposed score is:

`current minimum expected loss - expected future minimum expected loss - experiment cost`.

The cost must be expressed in the same utility units, or handled as a separate hard constraint. Information gain per dollar is a different objective and should not silently replace this calculation. A 2024 NeurIPS paper develops amortized experiment design explicitly optimized for downstream decision utility. Its contribution is a computational approach to this principle, not the invention of value of information. [Huang et al., 2024](https://papers.neurips.cc/paper_files/paper/2024/file/c59f05d7ab3638b138cc61f32e1a7cd1-Paper-Conference.pdf).

## A realistic first experience

After the temperature/time model has been checked, the person says: “I can make six more panels. Help me determine whether a shorter cure can work, and whether temperature changes the time effect.” Chat drafts the purpose, feasible settings, panel budget and a small number of candidate explanations for review.

The following is a proposed workflow, not a calculated six-panel recommendation:

1. Separate controllable settings from context such as batch, operator and actual oven temperature. Retain commanded and measured settings separately.
2. Review additive and interaction explanations. Plot where their predictions differ within the feasible region, including noise and parameter uncertainty.
3. Rank feasible *batches*, including intentional replication. Show expected benefit, uncertainty in that estimate, cost, and why alternatives rank lower.
4. Have the scientist accept a batch. Freeze model revision, transformation definitions, prediction basis, protocol and assessment rule before outcomes arrive.
5. Record actual execution and measurements, assess the frozen prediction, then refit and propose the next step. A poor check may justify revising the likelihood or mechanism before optimizing further.

The mathematical reason to account for noise is concrete: a wide outcome interval can mostly reflect irreducible panel variability. Sampling where that interval is widest can be wasteful. The design calculation should distinguish uncertainty in the latent response from measurement variation. In the current conjugate model this means preserving the joint posterior over coefficients and common variance, rather than independently sampling the marginal intervals shown in the UI. Batches likewise require joint predictions: six individually attractive points can be redundant. This implementation recommendation follows from the current [normal/inverse-gamma model](../R/regression.R) and the joint design formulation in the [2024 OED review](https://www.cambridge.org/core/journals/acta-numerica/article/optimal-experimental-design-formulations-and-computations/38BBD0DC1A0386FDF306B6C0167DF7D9).

For a first bounded implementation, use a finite candidate grid and a small batch budget. Posterior predictive simulation plus conjugate updating can estimate a target-uncertainty or decision-loss reduction. Evaluate whole batches or use explicitly labeled greedy conditional selection with repeated simulations; report Monte Carlo error. Do not label a heuristic “optimal” without the corresponding search guarantee. Include a “no worthwhile informative design” result and sensitivity to plausible alternative noise/model specifications. These are proposed acceptance requirements.

## Feature engineering as scientific model revision

Feature *construction*, feature *selection*, and deciding which new variable to *measure* are separate operations. A derived temperature-by-time term is not a new observation. Adding a humidity sensor is. Suppose should preserve that distinction and explain the scientific assumption behind each change.

For the coating case, a useful sequence of candidate revisions is:

| Candidate | Scientific question | What must be preserved |
|---|---|---|
| Centered temperature × centered time | Does the time effect depend on temperature? | Main effects, centering constants, units and interaction prior |
| log(time/reference time) or a smooth time effect | Do gains diminish with additional cure time? | Positive domain, transform definition and regularization |
| A mechanistic temperature/time transformation | Is a specified kinetic mechanism plausible? | Physical units and uncertain mechanism parameters |
| Batch intercepts or slopes | Does the relationship generalize across batches? | Batch identity and partial pooling |
| Noise varying with settings | Does the process become less reproducible in part of the space? | Mean and variability models reviewed separately |

These are hypotheses to check, not established facts about this coating. An Arrhenius-style candidate, for example, needs absolute temperature and an explicit kinetic assumption; estimating an activation parameter makes it a nonlinear model rather than a fixed preprocessing shortcut. The current two-predictor model cannot represent the full interaction model while retaining both main effects, so this needs an intentional model-family extension.

The practical Bayesian path is a reasonably rich, regularized reference model, followed by predictive checking and simplification if needed. Regularized horseshoe priors encode sparsity while also regularizing large coefficients; ordinary weakly informative priors may be simpler for a handful of scientifically chosen terms. Horseshoe methods are established work, not a new 2026 development. [Piironen and Vehtari, 2017](https://arxiv.org/abs/1707.01694).

Projection predictive selection asks which smaller model can preserve the reference model's predictive behavior. It is particularly relevant when measuring an extra predictor is expensive. The 2025 review gives a practical workflow; `projpred` supports custom reference models as well as common brms/rstanarm paths. This is more useful here than repeatedly adding whatever term gives the largest observed improvement. It does not establish causal importance, and correlated predictors may substitute for one another. [McLatchie et al., Statistical Science 40(1), 128–147, 2025; DOI 10.1214/24-STS949, published version](https://acris.aalto.fi/ws/portalfiles/portal/176405756/Advances_in_Projection_Predictive_Inference.pdf), [official projpred documentation](https://mc-stan.org/projpred/articles/projpred.html).

Flexible Bayesian modeling need not start with equation search. Additive and multilevel structure already work with projection predictive methods. brms supports smooth, Gaussian-process, nonlinear and distributional components, providing a plausible later external-model route under SUP-017. [Catalina, Bürkner and Vehtari, 2022](https://proceedings.mlr.press/v151/catalina22a.html), [brms formula documentation](https://paulbuerkner.com/brms/reference/brmsformula.html).

## What is newer

Verified work through 2026-09-08 strengthens two directions: designs that serve a downstream task, and uncertainty over constructed features or equations. The computational advances below are research methods; their benchmarks do not establish a production-ready Suppose integration.

- **Amortized adaptive design:** train a policy using simulated experiments so it can propose later experiments quickly, sometimes considering a sequence of future measurements. Attractive when many related campaigns justify substantial training; unnecessary for a small initial candidate-grid implementation. [Rainforth et al., published 2024](https://arxiv.org/abs/2302.14545). Decision-aware amortization is illustrated by the Huang paper linked above.
- **Task-driven design, June 2026:** Action-BED directly optimizes expected future loss on downstream actions, using joint model simulation and an evaluable loss. Its formulation avoids explicit posterior/marginal-likelihood estimation when learning design and action policies. This is closely aligned with asking which measurement improves a protocol decision, although it remains a preprint and requires its own numerical validation. [Rossa, Phillips and Rainforth, submitted June 22, 2026](https://arxiv.org/abs/2606.23662).
- **Cheaper policy training, UAI August 2026:** score-matching BED learns a score approximation separately from the design policy, reducing repeated policy-training costs. This matters when training many policies or serving repeated campaigns; the bounded conjugate example does not yet justify that machinery. [Phillips, Kerrigan and Rainforth, UAI 2026](https://proceedings.mlr.press/v337/phillips26a.html).
- **Projection predictive practice and broader families:** the 2025 review consolidates the workflow, and a 2025 journal article expands selection for finite-support discrete outcomes. This is an evolution of a mature method. [2025 published review, DOI 10.1214/24-STS949](https://acris.aalto.fi/ws/portalfiles/portal/176405756/Advances_in_Projection_Predictive_Inference.pdf), [Weber, Glass and Vehtari, 2025](https://link.springer.com/article/10.1007/s00180-024-01506-0).
- **Bayesian symbolic regression:** newer work puts uncertainty over equations themselves. A July 2025 discussion emphasizes ensembles of plausible expressions; a December 2025 preprint uses sequential Monte Carlo to approximate a posterior over expressions and reports noisy-benchmark improvements. Treat these as research directions, not a proven automatic mechanism-discovery feature. [Guimera and Sales-Pardo, 2025 preprint](https://arxiv.org/abs/2507.19540), [Bomarito and Leser, 2025 preprint](https://arxiv.org/abs/2512.10849).
- **Expression posterior sampling, UAI August 2026:** ERRLESS uses entropy-regularized reinforcement learning to generate symbolic expression structures. The paper targets posterior sampling and reports competitive Feynman-benchmark results. Its convergence statement should not be read as a guarantee that a finite trained policy has recovered the full posterior or discovered the true coating mechanism. [Boussif et al., UAI 2026](https://proceedings.mlr.press/v337/boussif26a.html).
- **Uncertainty over material descriptors, June 2026 preprint:** Bayesian support selection adds posterior probabilities and model averaging to SISSO's screened feature space, illustrating alternative descriptors on Heusler alloys. This is especially relevant to feature engineering in small materials datasets. Its uncertainty excludes discarded features. The reported CV uses globally fixed noise/prior scales derived from full data, so its interval calibration is conditional on that setup, not evidence from a fully nested pipeline. [Bhattacharjee, submitted June 2 and revised June 9, 2026; method and limitations](https://arxiv.org/html/2606.04042v2).

The compelling connection is to retain several plausible feature/mechanism models and ask which experiment separates their predictions. A newly discovered equation then motivates a prospective experiment instead of being presented as a scientific conclusion. There is direct methodological precedent: Clarkson and colleagues combine symbolic model discrimination with parameter learning. Their chapter was published January 12, 2026, but the preprint appeared November 29, 2022; it should not be described as an entirely new 2026 idea. [Published chapter](https://link.springer.com/chapter/10.1007/978-981-95-1446-5_7), [original preprint](https://arxiv.org/abs/2211.15860).

## Validation and staged recommendation

Repeatedly searching transformations against the same LOO scores can overfit the selection process. Preprocessing learned from data belongs inside validation folds; grouped panels/batches and temporal campaigns need splits matching the intended generalization. Prediction improvement does not show that a coefficient is causal or that a mechanism is true. Keep exploratory search history and confirm important discoveries prospectively. [Official loo cross-validation FAQ](https://mc-stan.org/loo/articles/online-only/faq.html). alloptr already has useful grouped/chronological resampling ownership to reuse, as noted above.

Recommended order, as product design inference:

1. **Next-measurement review:** a bounded extension of SUP-020, using the current posterior, explicit learning targets, feasible grids, noise, replication and full provenance. Build the required alloptr numerical adapter there rather than another campaign runtime in Suppose. Extend regression prospective commitments so the loop can be assessed honestly.
2. **Scientific feature proposals:** add interactions and a few reviewable transformations with units, rationale, priors, original model retention and paired predictions. Require main-effect hierarchy for ordinary interaction proposals. Preserve new measurements separately from derived columns.
3. **External reference models:** deliver the SUP-017 contract for joint posterior predictions, likelihood/noise, diagnostics, deterministic transforms, model identity and supported design calculations. Then integrate regularization, richer likelihoods and projection predictive simplification.
4. **Decision-aware design:** add SUP-019 preferences/costs, then evaluate expected decision improvement. Present sensitivity when plausible preferences change the recommended research.
5. **Equation-search experiments:** evaluate Bayesian symbolic regression only after the above validation and prospective loop work. Retain multiple expressions, dimension/domain restrictions and search provenance.

The first end-to-end acceptance case should show that the chosen measurement changes when the purpose changes, that replication can outrank another extreme point under a suitable noise model, and that an unresolved model check remains visible after a seemingly successful optimization.
