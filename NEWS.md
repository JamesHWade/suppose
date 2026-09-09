# suppose 0.0.0.9000

* `suppose_app()` and `suppose_example_app()` accept an ellmer chat object or constructor through `chat`. Object templates preserve provider and model configuration while creating fresh session state; existing factory arguments remain supported.

* Documentation now includes a concise introduction, eight task-oriented guides, evaluated statistical examples, and a redesigned pkgdown site.

* The workbench adopts the hex sticker's plum, lavender and cream palette, bold typography and fox mark; prior plots use matching colors.

* Chat can retry after cancellation without inheriting the earlier stop signal.
* The numerical example uses a keyboard-accessible correlation input, and saved-record upload feedback is visible beside the upload control on small screens.
* The CLI JSON inspection includes judgments, model references and research designs.

* `check_expectations()` and the workbench compare stated expectations with prior consequences, including explicit straight-line projections beyond elicited anchors. Unsupported judgments and the difference between mean uncertainty and batch variation remain visible.

* `record_model_reference()` retains attributed many-to-many claim/prior relationships separately from fitting and acceptance. Portable records now support schema 12.

* `judgment()` identifies reference conditions for comparisons and shape expectations. The workbench can review and retain these answers, ranges and explicit quantiles without fitting them; `record_judgment()` preserves the current candidate and earlier judgments.

* `design_regression()` compares next measurements using alloptr's exact Bayesian
  design engine. Chat can prepare targets, independent replicates, budgets and
  explicit costs/preferences for review. `record_research_design()` retains the
  planning choice and model limitations without executing or freezing a test.

* Chat can prepare one reviewed import from a pasted CSV with `draft_measurements`.
  **Import a table** maps outcomes and numeric predictors together, retains the
  original table and provenance, and protects manual edits and stale previews.
* Changing tools or models preserves Deputy's archived results through session
  transfer, fixing the reserved result-reader error when enabling R. Current
  record context is supplied automatically, and validation failures return compact
  messages without captured stack frames.
* Regression prior previews show the implied mean change across each predictor's
  observed range, making overly restrictive effect scales visible before fitting.
* Chat distinguishes unknown-noise regression from the older known-SD form,
  practical improvement from economic payoff, and applying a revision from
  accepting its interpretation as reviewed.

* Chat can prepare a regression prior form with `draft_regression`. The
  `/regression` flow reviews priors, fits unknown measurement noise, inspects
  predictive discrepancies, compares an added predictor, and retains a reasoned
  model choice (including neither) without replacing earlier results.
* `fit_regression()` performs exact normal/inverse-gamma inference and exact
  leave-one-out refits. Joint predictive checks report simulation uncertainty;
  borderline checks remain distinct from clear mismatch flags.
* `regression_predictors()` and `record_predictors()` link numeric predictor
  measurements to existing outcome IDs with source and unit provenance.
  `regression_prior()`, `plot_regression()`, `predict_regression()` and
  `record_regression()` support prior inspection, new-case predictions, visual
  checks and portable reviewed results.

* Chat now fills the model-extension and sensitivity forms through real tools,
  prepares previews, and preserves existing values for omitted fields. Suggested
  defaults are labeled; newer manual edits require an explicit replacement choice.
  Retained results preserve the original chat suggestion and reviewed settings.
* `compare_extension()`, `record_extension()` and `plot_extension()` compare one
  added predictor under a raw-unit and meaningful-change coefficient prior.
  `/extend` shows aligned predictions, new assumptions, optional implausible
  outcome probabilities, and a reviewed alternative alongside the original model.

* `sensitivity_analysis()`, `record_sensitivity()` and `plot_sensitivity()` compare
  prior strength and likelihood weight using exact normal calculations. The
  `/sensitivity` workbench flow previews and retains selected outputs, failed
  computations, exploratory assessment comparisons and actionable follow-ups.

* `commit_test()`, `assess_test()` and `plot_test()` freeze a future sample-mean
  comparison and retain its later assessments. The workbench adds `/test` and
  **A future test**, with preview/confirm controls, planned CSV templates,
  exposure and protocol checks, and explicit missing/deadline outcomes.

* R execution now uses Deputy's conversation-owned persistent process. Reopening,
  switching conversations, or changing the agent configuration starts fresh.
  Code, ordered output, static plots, and scientific input references remain in
  a portable analysis journal, independently of model context compaction.
* `update_prior()`, `record_update()` and `plot_update()` support analytic normal
  updates with positive known measurement SDs and explicitly independent units.
  The workbench previews and retains updates separately from the original prior,
  with distinct computation, prior-predictive and measurement-variation checks.
* Observation times may explicitly be `unknown` when a source does not document
  them. A reproducible retrospective PlantGrowth example exercises the full path.

- Prior cards and the Record drawer offer density, interval, and interactive
  exploration tabs. Plots regenerate from saved judgments when history opens.
- `plot_prior()` returns editable ggplot2 views, patchwork compositions, ggdist
  intervals, and optional Plotly widgets, with analytic uncertainty summaries.

- Prior elicitation now guides mean-interval and variability judgments. Inline
  and Record charts distinguish mean priors from future-measurement predictions.

- Model replies offer native shinychat next-step suggestions. Draft interpretations
  have inline Apply, Correct and Decline controls with persistent decision state
  and checks against stale drafts.

- `suppose_app()` adds a Tools modal for tool requests, optional Deputy file, web,
  R and shell bundles, execution limits, context settings and run activity.

- Inquiry tools now return explicit JSON, avoiding raw-list deprecation warnings
  in ellmer 0.5 while preserving their structured internal receipts.
- The measurements drawer previews CSV imports and retains them with the exact
  claim revision. Saved conversations and CLI inspection include measurements.
- `import_observations()` retains measurement provenance, missingness, potential
  duplicate rows, exposure, and explicit unit conversion.
- `record_observations()` attaches measurements without changing accepted claims
  and prevents duplicate source/measurement reuse. Bundles now support schema 4.


## First-session quality

* CLI inspection now includes qualitative meaning and review state. Prediction
  requests explain when a record has no numerical candidate.
* `apply_assistant_proposal()` accepts attributed reviewer corrections while
  preserving the exact original suggestion. Corrections clear numerical models
  and results from the new revision.
* `suppose_app()` separates assistant ideas from user expectations and assumptions,
  retains complete source statements, and provides a direct correction form.
  Pending suggestions must be resolved before accepting a retained revision.
* `suppose_app()` gives concrete help when a user cannot define an outcome,
  preserves hypothetical questions and negative expectations, and avoids
  irrelevant numerical-model explanations. Wording checks do not replace review.
* `suppose_app()` handles unknown model fields and tool-only responses, and keeps
  an existing suggestion unchanged during discussion or cancellation.

## Initial prototype

* First local prototype includes an R API, a Shiny workbench, and a Rapp CLI.
* `claim()` and `revise_claim()` retain original wording, attribution, scope,
  assumptions, and revision ancestry without requiring numerical beliefs.
* `fit_prior()` fits explicit mean quantiles for a two-condition normal model,
  reports mismatch, and exposes correlation and batch variation assumptions.
* `judgment()` retains quantitative, ambiguous, and qualitative answers with
  their intended meaning and information basis.
* `predict_prior()` returns seeded draws and exact normal contrast summaries.
* `record_revision()`, `accept_revision()`, `write_record()`, and `read_record()`
  preserve review history and stored computations in validated JSON bundles.
* `suppose_app()` supports manual inspection, correction, review, and reopen,
  with local guidance and optional ellmer suggestions through shinychat.

* Add `suppose_muse()` for opt-in Muse Spark Contributor inference through OpenRouter.
* Add reviewable assistant proposals for claims, judgments and assumptions, with
  source-quote checks and previews computed by the statistical APIs.
* Retain conversation, model and tool receipts in schema-2 bundles and link them
  to explicit acceptance. Schema-1 records remain readable.
* Reject stale proposals and late cancelled tool calls; retain a manual workflow
  when a model is unavailable.

* `suppose_app()` now starts with an empty conversation and a general inquiry
  record, with optional examples and analytical methods.
* `suppose_agent()` supplies a Deputy Agent directly to shinychat, with bounded
  inquiry tools, execution limits and retained run provenance.
* `accept_interpretation()` records agreement about meaning without requiring
  a numerical model. Numerical candidate acceptance remains distinct.
* `claim()` can retain qualitative expectations as well as assumptions and open
  questions. A changed problem cannot inherit an unrelated numerical model.
* `suppose_example_app()` preserves the detailed temperature demonstration as an
  optional worked example.
* Schema-3 bundles retain conversation history, including conversations that
  have not produced a numerical model. Earlier bundle versions remain readable.

* Give the empty conversation a welcome and editable starting prompts. Move the
  developing record into shinychat's resizable drawer, opened from the footer,
  with a suggestion-ready indicator and model details beside it.

* `suppose_app()` adds `/record`, `/model`, and `/help` for operating the app.
* `suppose_app()` adds model search and compact pricing, with filters and output
  limits under Advanced options. Model changes retain conversation and record
  state; run receipts identify their producing model.
