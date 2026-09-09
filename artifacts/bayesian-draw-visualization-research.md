# Bayesian draws as an interface for reasoning

Research memo, 2026-09-09. This is a design recommendation, not an implementation specification. Sources were checked live; the local capability notes below come from the concurrent source audit.

The strongest opportunity for Suppose is to let people inspect **plausible realizations of their model**, while keeping a stable distribution summary visible. A draw can show what a belief implies for several quantities together; it is more than a dot added to a density plot. The available evidence supports particular tasks and representations, not a universal claim that animation or dots improve Bayesian reasoning.

## Six core sources

### 1. Hypothetical outcome plots: strongest evidence for comparisons

Jessica Hullman, Paul Resnick, and Eytan Adar (2015), *Hypothetical Outcome Plots Outperform Error Bars and Violin Plots for Inferences about Reliability of Variable Ordering*, PLOS ONE. [Primary article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0142444).

**Empirical result:** In their controlled study, animated draws supported more accurate judgments about ordering two or three quantities than error bars and violin plots. For most questions involving one quantity, performance was similar across the representations. Frames could be paused and stepped through.

**Limits:** The tasks concerned properties of Gaussian outcome distributions, framed as solute concentrations; the study intentionally separated visual probability estimation from statistical inference. It does not establish improved scientific decisions or posterior understanding in Suppose. Finite viewing introduces sampling error, and viewers must integrate information across frames. Fixed axes reduce that burden.

**Implication:** A two-condition comparison is a better first HOP use case than an animated univariate posterior. Keep numerical probabilities and a static overview available.

### 2. Quantile dotplots: countable probability mass

Matthew Kay, Tara Kola, Jessica Hullman, and Sean Munson (2016), *When(ish) is My Bus? User-centered Visualizations of Uncertainty in Everyday, Mobile Predictive Systems*, CHI. [Authors' institutional page and paper](https://idl.uw.edu/papers/when-ish-is-my-bus), [DOI](https://doi.org/10.1145/2858036.2858558).

**Empirical result:** Their transit prediction experiment reported a roughly 1.15-fold reduction in the variance of probability estimates relative to density plots, and more confident estimates. Quantile dotplots discretize a continuous distribution into equal-probability pieces for a compact display.

**Limits:** This is modest, context-specific evidence from transit prediction, not proof of general superiority or better calibrated confidence. Confidence and accuracy are different outcomes.

**Implication:** Offer a countable alternative for threshold questions, with a legend such as “Each dot represents 1% of this distribution.” Quantile dots are representative probability mass, not observed measurements or independent random draws. Do not call the dots “100 simulations.”

### 3. ggdist: an appropriate R implementation foundation

Matthew Kay (2024), *ggdist: Visualizations of Distributions and Uncertainty in the Grammar of Graphics*, IEEE TVCG 30(1), 414–424. [Author-hosted paper](https://mucollective.northwestern.edu/files/2023-ggdist.pdf), [DOI](https://doi.org/10.1109/TVCG.2023.3327195), [official package documentation](https://mjskay.github.io/ggdist/).

**Contribution:** A distribution-oriented extension to the grammar of graphics, including slab/interval, dot, and ribbon representations. The official documentation supports both samples and analytical distributions, including `distributional` and `posterior::rvar` objects.

**Limits:** This is principally a grammar/software contribution, not a controlled demonstration that any one geom improves every task.

**Implication:** Use the ecosystem rather than inventing a custom density or dot layout. Suppose's analytic Normal and Student-t marginals can be shown directly; generating Monte Carlo draws solely to estimate a known univariate density adds avoidable approximation noise.

### 4. Visualization in Bayesian workflow: simulate observable consequences

Jonah Gabry, Daniel Simpson, Aki Vehtari, Michael Betancourt, and Andrew Gelman (2019), *Visualization in Bayesian workflow*, JRSS A 182(2), 389–402. [Primary manuscript](https://arxiv.org/html/1709.01449v5), [DOI](https://doi.org/10.1111/rssa.12378).

**Contribution:** Case studies show visualization supporting model construction, prior predictive assessment, model checking, and revision. The authors recommend a flipbook of prior-generated datasets and compare observed data with complete posterior predictive replications. They emphasize that joint priors matter through their interaction with the likelihood.

**Limits:** This is workflow guidance illustrated through applied examples, not an interface trial. Posterior predictive checks reuse fitted data and can be weak for statistics directly captured by model parameters; for a Gaussian model, checking only the mean can miss consequential failures. A successful check is not proof of the model.

**Implication:** Preserve whole replicated datasets. Later add scientific checks of spread, asymmetry, extremes, or residual structure alongside the observed data. Keep predictive checking distinct from displaying parameter uncertainty.

### 5. Recent predictive-check guidance: the graphic also has assumptions

Teemu Säilynoja, Andrew R. Johnson, Osvaldo A. Martin, and Aki Vehtari, *Recommendations for visual predictive checks in Bayesian workflow*. [Primary PDF](https://www.journalovi.org/2025-sailynoja-visual-predictive-checks/index.pdf), [arXiv record](https://arxiv.org/abs/2503.01509).

**Status checked:** The retrieved PDF is dated July 22, 2026 and explicitly marked **under review** on the Journal of Visualization and Interaction experimental track. The arXiv submission began in 2025; do not describe this as an accepted 2025 article.

**Contribution:** Examples and recommendations examine KDEs, histograms, and quantile dotplots for predictive checks. KDE bandwidth can hide structure, and boundaries or discrete components require care. Per-bin or pointwise summaries omit dependence between parts of a distribution. No single check reveals every model failure.

**Limits:** These are methodological demonstrations and recommendations, not a universal empirical ranking. Dotplots also have familiarity, layout, and discrete-data limitations.

**Implication:** For continuous Gaussian outcomes, start with simple observed-versus-replicated comparisons. Do not indiscriminately smooth future count, bounded, or mixed data, and do not equate pointwise ribbons with complete plausible datasets.

### 6. Joint draws: an existing data contract, not an animation trick

Matthew Kay and the posterior developers, *rvar: The Random Variable Datatype*. [Official vignette](https://mc-stan.org/posterior/articles/rvar.html), [draw-wise iteration documentation](https://mc-stan.org/posterior/reference/for_each_draw.html).

**Software contract:** `draws_rvars` represents multiple variables in a joint sample. The `rvar` format keeps a draw dimension while supporting arithmetic; draw-wise iteration resolves all variables at the same draw index.

**Limits:** Software documentation establishes mechanics, not human-performance benefits. Matching indices only preserve dependence when the samples were generated jointly in the first place.

**Implication:** Give each realization a stable draw ID. Derive differences, predictions, and highlighted marks from that same realization. Do not independently sort or resample marginal columns and then present them as a joint model draw.

## Recommended bounded first feature

**Proposal, informed by the evidence above:** Add an “Explore possible outcomes” view to the existing two-condition prior prediction. This is already the smallest local surface with aligned draws: `predict_prior()` retains mean and batch quantities for low/high conditions and their differences, while `inquiry_prior_visual()` currently drops those draws.

The default remains a stable, labeled distribution summary. A countable dot view answers “How much probability is above this scientifically meaningful threshold?” An optional draw scrubber shows the two condition means, their difference, and the corresponding simulated batch comparison together. Distinguish the true mean contrast from the result a future batch might show; state the batch size. One index controls all highlighted quantities. Offer manual next/previous before optional animation; respect reduced-motion settings.

Use exact analytic probabilities where available. Label quantile dots as probability mass and random frames as model realizations. A displayed frame count is not an exact probability estimate. Cache a reproducible draw set so resizing, tab changes, and narration do not generate a different story. A changed scientific model should generate a new set with visible provenance.

This recommendation is a product design hypothesis. Evaluate it with concrete questions: can someone distinguish mean uncertainty from future batch variability, estimate the probability of a meaningful improvement, and explain why the two conditions move together? Assess answers and comprehension, not just preference for a graphic.

## Next extension: coherent regression draws

The source audit found that regression predictive checks already generate shared variance, jointly sampled coefficients, and complete outcome replications internally, but retain only discrepancy statistics. `predict_regression()` exposes marginal analytic Student-t summaries. Therefore a regression curve explorer requires a retained joint-draw contract first.

For the normal-inverse-gamma model, each realization should use one variance draw and a coefficient vector sampled conditionally on that variance. Evaluate that same vector across the predictor grid; add conditionally generated observation noise only for predicted observations. Drawing each grid point independently from its marginal Student-t produces incorrect trajectories. Likewise, marginal quantiles at successive grid points are not a sampled curve.

Once this contract exists, a small collection of plausible mean curves plus a selected complete realization can complement interval ribbons. Observed-versus-replicated datasets can then support predictive checks. These are **design proposals**, not features already present.

None of these features requires MCMC. Direct samples from analytic posteriors still have finite-sample Monte Carlo error when estimating quantities, but trace plots, divergent transitions, or convergence dashboards would misdescribe Suppose's current computation.
