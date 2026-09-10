# Explore the world implied by a model

Authorized: build the first brms walkthrough and provide starting models.

The first slice accepts univariate brms predictions over an explicit scenario
table. It records model structure, supplied scientific context, coherent draws,
run provenance, and user-reviewed implications. Bundled examples are frozen
predictions from real brms fits to synthetic data, reproducible from source;
opening them requires neither brms, Stan compilation, nor a model provider.
They are simulations, never empirical evidence about a real system.

- [x] Implement a bounded brms adapter and validated portable snapshots.
- [x] Fit and bundle contrasting example models with reproducible source.
- [x] Build an accessible visual walkthrough, scenario controls and reviews.
- [x] Preserve reviewed claims, model links and challenges on save/reopen.
- [x] Connect the app and chat context without allowing inferred acceptance.
- [x] Verify numerical results, persistence, app behavior and isolation.
- [x] Document usage and limitations; run package and documentation checks.

Stan and tidymodels adapters, automatic refitting and experimental-design
computation for arbitrary external models remain subsequent work. A challenge
from this walkthrough is a reviewed question, not a frozen numerical test.

Validation: [Model-world acceptance](artifacts/model-world-review.md).
