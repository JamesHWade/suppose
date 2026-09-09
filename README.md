# Suppose <img src="man/figures/logo.png" align="right" width="120" alt="Suppose hex sticker: a curious fox watching dandelion seeds drift along different paths." />

Make beliefs explicit, explore their consequences, and identify what evidence
would change your understanding.

Suppose starts with a conversation about a question, belief, or decision. It helps
you clarify what you mean, make expectations and assumptions explicit, and keep
a reviewed record of what could change your mind. A numerical model is optional.

## Try the workbench

From this project directory:

```r
pkgload::load_all()
suppose_app()
```

This opens the development shinychat full-page layout, with a native conversation sidebar. Open **Record** in
the chat footer to inspect or edit the developing inquiry in a resizable drawer.
The footer signals when a proposed interpretation is ready for review. Without credentials, the labeled local guide retains your messages and the
record editor remains usable. It does not pretend to interpret messages with AI.

To connect Muse Spark Contributor, configure `OPENROUTER_API_KEY` locally and run:

```r
suppose_app(agent_factory = suppose_agent)
```

`suppose_agent()` creates a **Deputy Agent** with an ellmer model client. The app
passes that Agent directly to `shinychat::chat_server()`. Deputy owns execution,
permissions, usage limits, streaming and cancellation. Suppose supplies bounded
inquiry tools and owns the reviewable scientific record. The shipped Agent
subclass handles shinychat's spliced message arguments for the installed Deputy
version, then delegates to Deputy's governed streaming method.

For a different configured ellmer provider:

```r
suppose_app(agent_factory = function() {
  suppose_agent(chat = ellmer::chat_openai(model = "your-configured-model"))
})
```

1. Start with your own question, or edit one of the optional starting points.
2. Clarify scope, time horizon, expectations, assumptions and open questions
   through the conversation. Open **Record** to review proposed interpretations.
3. Correct a proposal conversationally or use **Correct suggestion** to edit it
   before applying. You can also decline it or apply it unchanged as a revision.
4. Record why the interpretation expresses your meaning and what could change
   your mind. You can accept an interpretation without adopting a numerical model.
5. With an agent connected, conversations, records and pending suggestions save
   automatically. Use the sidebar to reopen them or download a portable JSON copy.
   Apply changes in the manual editor before switching conversations.

Most substantive model replies offer clickable next steps written for the current
conversation. Clicking a suggestion sends its displayed prompt. Suggestions are
requests to explore or draft; they do not accept a record or grant tool access.

When a numerical prior is elicited, the chat card shows the two mean priors and
the implied mean difference alongside future-measurement variation. The same
charts are available in the Record panel. They visualize supplied beliefs and
assumptions, before new observations.

Draft interpretations appear as review cards directly in chat. Expand **Review
details**, then **Apply interpretation**, **Correct**, or **Decline**. Applying
adds a revision; accepting its meaning remains a separate review in the Record
panel. Cards retain their decision state when you reopen a conversation, and old
drafts cannot act on a newer suggestion.

Open **Tools** in the footer (or type `/tools`) to turn capabilities on or off.
Each switch has a short description and takes effect immediately. Ask in chat
to use the enabled tools. The **Request** tab also lets you supply a tool's inputs
and send a request or insert it in the composer.

The switches enable file/data reading, file writing, web tools,
R execution or shell commands. All optional bundles start disabled. File writes
are restricted to the chosen working folder; reads use the process's file access.
R and shell are trusted execution tools with the local account's access, not an
OS sandbox, and can also write or use the network. Settings apply to the current
open session and are preserved when choosing another model. Saved conversations
do not automatically enable broader access.

The **Settings** tab configures the working folder, per-response requests, tool calls, tokens and estimated
cost, plus automatic context compaction and large-result offloading. Token/cost
limits can overshoot by one model response. **Activity** shows the last recorded
response's usage and tool outcomes, with a stop button during execution. These
receipts travel with saved history. Exploratory results from general tools do
not automatically become attached evidence or accepted Suppose models.

Local history lives in `.suppose/conversations` under the working directory and
survives app restarts. Set `history_dir` (or `options(suppose.history_dir = ...)`)
to choose another location; `NULL` disables history. The local app shares that
directory across browser sessions, so this is a single-user configuration, not
hosted authentication. Native search, rename, delete and conversation URLs are
available; there is no automatic size-based eviction. The local guide without
an agent still uses manual JSON export. Correct prior messages in a new message
or the record editor: message branching is disabled until record revisions can
follow the same branches. Import a portable bundle from a new conversation.

The assistant keeps its possible explanations and next steps under **Ideas to
consider**. Applying an interpretation does not adopt those ideas. Proposed
expectations and assumptions quote complete user statements with source context
available for review. These wording checks preserve qualifications; they do not
certify that the assistant classified the statement correctly.

Direct corrections retain the exact assistant suggestion and the reviewer's
changes separately in history. Correcting an interpretation removes its
proposed numerical model from the new revision, so results cannot silently
follow a changed meaning. Apply, correct, or decline a pending suggestion before
accepting the retained interpretation.

### Commands and model selection

Type `/` to discover three app commands in a connected conversation, or use the
**/** button in the footer: `/record` opens the developing record, `/model` opens
the model picker, and `/help` lists the commands. Explore questions, assumptions,
and predictions through the conversation.

Click the model name in the footer to search available OpenRouter models, see the
current selection and compare compact token pricing. **Advanced options** holds
provider and price filters, output-token limits, context details and catalog
refresh. Catalog access requires `OPENROUTER_API_KEY`; loading it makes no
inference request. **Use model** changes the model for subsequent messages,
retaining the conversation, inquiry record, and pending proposal. Switching is
blocked while a response is running.
Completed Deputy run receipts include the model identifier. Account privacy
settings and provider availability still govern inference.

Contributor permits prompts and outputs to be used to improve Meta's products.
Conversation and requested record context are sent to the provider. Saved bundles
include messages and applied proposal provenance; credentials are excluded.
Unapplied suggestions and unretained editor changes are not saved as revisions.

The available numerical method compares two jointly normal uncertain means at
numeric conditions, with supplied central 90% intervals, correlation and known
normal measurement variation. The assistant should identify when that method
fits; it cannot invent a method for other problems or treat a plausible range as
a probability interval. Unsupported analyses remain explicit open questions.
The model is not a causal estimator.

The temperature example is now optional: use **Load worked numerical record**
from the starting points, or open its detailed statistical form separately:

```r
suppose_example_app()
```

The UI needs `shiny`, `bslib`, and the compatible development build of `shinychat`
recorded in DESCRIPTION. AI conversations also need `ellmer`, `deputy`, and `R6`.
A clean isolated installation was verified on macOS with R 4.6 using public
Shinychat commit `eb024589465f5227405d567854b96cc87e5bb9ac` from the repository's
`pkg-r` directory, Deputy `4a8ee639df8c5e5e32567cb706b722f14732c923`, and ellmer
0.5.0. These explicit references reproduce the tested development stack:

```sh
ir tool install local::"$(pwd)" \
  --with github::posit-dev/shinychat/pkg-r@eb024589465f5227405d567854b96cc87e5bb9ac \
  --with github::JamesHWade/deputy@4a8ee639df8c5e5e32567cb706b722f14732c923
```

Core numerical and measurement APIs do not require the UI packages. Other
operating systems and screen-reader behavior still require validation.

Real Deputy tool execution and shinychat streaming have been verified with a
local scripted server and live Muse responses. Fictional live walkthroughs cover
coordination, product demand, and measurement questions, including corrected
interpretations and saved records. Intended-user acceptance remains open.
See [ACCEPTANCE.md](ACCEPTANCE.md) for the checked boundaries and reproducible probes.

## Work from R

```r
library(suppose)

record <- suppose_example() # Draft + two proposed candidates
candidate <- record$revisions[[3]]$candidate
prediction <- predict_prior(candidate, seed = 47)
print(prediction)
plot(prediction)

record <- accept_revision(
  record,
  author = "Tutorial reviewer",
  reason = "Shared uncertainty reflects the intended belief.",
  challenge = "Compare independently prepared batches under randomized cure temperatures."
)
path <- tempfile(fileext = ".json")
write_record(record, path)
reopened <- read_record(path) # No recomputation
```

Create your own incomplete `claim()`, preserve a correction with `revise_claim()`,
and record original answers with `judgment()`. Ranges without probabilities and
qualitative answers remain unresolved. `record_revision(..., judgments = list(j))`
can retain these answers without fitting them.

`fit_prior()` supports exactly two ordered conditions, explicit quantiles about
uncertain means, a supplied correlation, and two known batch SDs. It returns
elicited-versus-implied quantiles and discrepancies. Failed correspondence is
visible and prevents acceptance. It does not manufacture probabilities from
plausible ranges.

## Visualize and revise

Prior cards and the Record drawer now offer **Densities**, **Intervals**, and
**Explore** tabs. Explore supports Plotly hover, zoom, and legend toggles. The
same saved judgments regenerate these views when a conversation is reopened.

`plot_prior()` returns an editable plot. Use ggplot2 layers to change labels or
scales, patchwork to compose views, and `ggsave()` to export PNG, SVG, or PDF:

```r
entry <- suppose_example()$revisions[[3]]
p <- plot_prior(entry$candidate, view = "contrast")
p + ggplot2::labs(title = "Consequences of the elicited prior")
plot_prior(entry$candidate, view = "intervals") # ggdist
plot_prior(entry$candidate, view = "contrast", interactive = TRUE) # Plotly
```

Install the visualization dependencies with the application dependencies:

```r
install.packages(c("ggplot2", "patchwork", "ggdist", "plotly"))
```

`dev/visualization-examples.R` builds a local gallery including ggplot2,
patchwork, ggdist, Plotly, a gt summary table, and a Leaflet earthquake map.
The gallery writes editable-code examples and rendered artifacts under
`artifacts/visualizations/`. SVG export uses svglite. Leaflet map tiles need
an internet connection; the example points come from R's built-in `quakes` data.

The built-in prior views are available in the app now. General conversational
plot execution is being developed in Deputy. Installing Plotly, Leaflet, or gt
does not by itself make those objects render through the current text-only
Deputy R tool. The local worker spike is retained for validation, but is not
wired into the app while that upstream contract is being developed.

## Terminal workflow

The package supplies `exec/suppose` using Rapp. With the external
[ir launcher](https://r-lib.github.io/ir/tools.html):

```sh
rx --from "local::$(pwd)" suppose --help
ir tool install "local::$(pwd)"
suppose demo example.json --seed 47
suppose inspect example.json
suppose inspect example.json --json
suppose predict example.json --seed 47 --n 4000 > predictions.json
```

`demo` refuses an existing destination. `predict` requires an explicit seed and
emits a separate JSON computation without changing the input bundle. Diagnostics
go to stderr; JSON goes to stdout. Failures return a nonzero status. `app` needs
UI packages in the ir environment (`--with shiny --with bslib --with shinychat`).
For an existing R installation, `install_suppose_cli(destdir = "your/bin")` makes
a launcher using its current library rather than an ir-managed library.

`inspect` also displays qualitative interpretations and their open questions.
Its JSON includes the latest claim and review alongside any numerical summary.
`predict` explains when a record has no numerical candidate; a qualitative
inquiry does not require one.

## Scientific scope

The first method fits normal quantiles by least squares. It represents jointly
normal uncertain means and independent normal batch noise with fixed SDs.
The correlation is **not identified by the marginal intervals**. Normal support
allows negative strengths; the diagnostic reports that probability. A positive
family may be preferable when that mass is consequential. This version does not
fit a lognormal model, observation data, causal effects, or intermediate
response curves. Two temperatures cannot establish monotonicity.

Elicitation fit measures correspondence with stated judgments. Simulation shows
consequences of assumptions. Neither is empirical validation or a universal
confidence score. Acceptance records a person's review, not scientific truth.

See [the acceptance report](ACCEPTANCE.md), [contributor workflow](CONTRIBUTING.md),
[concept](CONCEPT.md), [domain vocabulary](CONTEXT.md), and [backlog](BACKLOG.md).

## Retain measured observations

Open **Record → Measured observations**, choose a CSV, describe its source and
protocol, declare prior exposure and intended use, then preview and attach.
Save the conversation and record to retain the measurements. Importing does
not fit a model or turn observations into an independent test.

The narrow CSV format has six columns:

```csv
observation_id,condition,outcome,batch,specimen,observed_at
m1,warm,10,b1,s1,2026-09-08T12:00:00Z
m2,cold,,b2,s2,2026-09-08T12:00:00Z
```

These are invented example rows. Blank outcomes remain missing. IDs are stable
within a source; batches and specimens may repeat. Times must be UTC. The same
workflow is available from R:

```r
record <- elicitation_record(claim(
  "Warm conditions may produce higher voltage", "Scientist", units = "mV"
))
measurements <- import_observations(
  "measurements.csv", source = "lab:run-1", protocol = "voltage-v1",
  author = "Scientist", units = "mV", role = "exploration", exposure = "unknown"
)
record <- record_observations(record, measurements, reason = "Inspect the run")
write_record(record, "record-with-measurements.json")
```

Or use `suppose observe --help` through the installed CLI. `inspect --json`
includes the original and converted rows with their provenance. Explicit unit
conversion uses `outcome * scale + offset`; set `target_units` to match the claim.
Previously explored outcomes cannot be designated for assessment, and outcomes
already used in the prior cannot be designated for updating. These protections
rely on honest exposure and stable source identities.

See [OBSERVATIONS-REVIEW.md](OBSERVATIONS-REVIEW.md) for validation and limits.

This workspace uses the shinychat development revision recorded in DESCRIPTION
(`eb024589465f5227405d567854b96cc87e5bb9ac`) for native structured tool UI
and history. It is installed in the main R library used by the demo launchers.

## Run calculations and learn from measurements

Enable **Run R code** in Tools, then ask for a calculation or plot. Deputy owns
one persistent R process for the open conversation. Follow-up requests can reuse
its variables. Switching or reopening a conversation, or changing the agent's
configuration, starts a fresh process. Recorded plots remain available; recreate
variables from the saved code when needed. Static base, ggplot2, grid and
patchwork plots are supported. Arbitrary interactive widgets and rich HTML
tables are not supported by this runtime yet.

**Record → Saved R analyses** retains code, ordered output, PNG plots, outcomes,
source requests, and exact prior/measurement references independently of model
context compaction. These references identify available context; they do not
certify that generated code implemented the assumptions correctly. Save/reopen
bundles contain data only and do not execute the stored code.

**Record → Learn from measurements** previews and retains an analytic normal
update using explicitly selected, update-designated observations. Map the two
condition labels and confirm independent measurement units. Positive measurement
SDs are treated as known. The result keeps the original prior and separates
posterior uncertainty from future-measurement variation and model checks.
Paired/clustered models, inferred measurement SDs, and general inference engines
remain outside this first method.

For a reproducible real-data example, run `Rscript dev/plantgrowth-acceptance.R`.
The PlantGrowth example is retrospective; its prior and fixed SD are explicitly
illustrative analyst assumptions. It does not attribute those assumptions to you
or claim independent prospective validation.

**Record → A future test** (or `/test`) freezes a prior or retained update,
planned measurement IDs, source, protocol, deadline and predictive interval.
Review the preview, then freeze before examining the designated outcomes.
Download the planned CSV, fill outcomes and measurement times, and attach it as
unseen assessment data. Preview and retain the assessment against the original
commitment, even if the claim has since changed.

This first rule compares the second sample mean minus the first, using independent
normal measurements with fixed known SDs. It requires all planned outcomes; an
incomplete cohort waits before its deadline and becomes inconclusive afterward.
Unknown times, exposure or protocol mismatches also prevent a numeric verdict.
An interval match does not establish claim truth, global model fit or causality.
The explicit exposure declaration is not independently verified by a timestamp.

Run `Rscript dev/prospective-acceptance.R` for a clearly synthetic lifecycle with
a simulated clock, including a retained assessment, later claim revision and
missing-at-deadline example. These invented outcomes are not prospective evidence.

**Record → Check sensitivity** (or `/sensitivity`) compares a retained update
under separately selected prior-strength and likelihood-weight powers. Power 1
is the original model. Select the mean difference, probability above the claim
threshold, and/or retained test assessments; set changes worth reviewing in
outcome units and percentage points. Preview the table and plots, then retain
the comparison. A button drafts a review of the latest retained finding in chat.

This is exact analytic normal power scaling. It does not change distribution
shapes, dependence assumptions or physical measurement SDs. Failed computations
remain visible. Alternative intervals for matching test assessments are explicitly
exploratory and leave original commitments and assessments intact. No selected
threshold being reached is not a global robustness certificate.

`Rscript dev/sensitivity-acceptance.R` generates synthetic sensitive, insensitive
and assessment-boundary examples. The [priorsense evaluation](dev/priorsense-evaluation.md)
records the adapter test and implementation choice.

## Review a model extension from chat

Ask, for example, "Add duration in minutes, centered at 60, with a meaningful
change of 10 minutes; prepare the form with starting defaults." The agent calls
`draft_model_extension` to fill **Record → Review a model extension** (`/extend`)
and prepare the comparison. You can adjust the values or retain the reviewed
alternative. Chat can also call `draft_sensitivity` to prepare the sensitivity
form. Omitted fields preserve your existing settings; routine defaults live under
**Adjust starting assumptions** or **Adjust comparison settings**. If you edit
while chat works, your edits stay until you explicitly choose the incoming draft.

The extension compares the original prior with one shared additive normal
coefficient, independent of the original means. It shows the consequence of
using the same coefficient prior per raw unit versus per meaningful change.
Optional plausible outcome bounds show the probability falling outside them.
At matching added-predictor values, the shared effect cancels from the original
mean contrast. The comparison also labels its new straight-line interpolation
and extrapolation assumptions; the original two judgments did not imply them.

Defaults are suggestions to review, not attributed beliefs. Retaining saves the
scientific reason, selected scaling, predictions and original chat draft alongside
the original model. Extended-model fitting, interactions and automatic prior
adjustment remain unsupported; existing update and test methods keep their
original model. Pending chat form drafts persist in native conversation history;
portable record downloads include form provenance after the result is retained.

Run `Rscript dev/extension-acceptance.R` for a synthetic scaling demonstration.

## Fit, check and revise a Bayesian regression

Paste your CSV table into chat and ask to prepare it for model updating. The
`draft_measurements` tool fills **Record → Import a table** with the outcome,
measurement IDs, predictor columns, units, source and exposure. Review the
mapping, then click **Attach reviewed table**. Outcomes and predictors are
attached together; no manual CSV split or R permission is needed. You can also
paste or upload CSV directly in that panel. The original table, reviewed mapping,
collection details and chat provenance remain in the saved record. A collection
date without a time stays a collection note; no time of day is invented.

The table importer handles up to 500 rows and two numeric predictors. Unknown
batch/specimen identities remain unknown, and fitting still requires an explicit
review of independent measurement units. Missing outcomes remain recorded and
cannot silently disappear into a regression fit. Scientific decisions require
review; routine current-record context is supplied to chat automatically.

**Record → Fit and compare models** (`/regression`) closes a bounded model-revision
loop. Start with retained update-designated outcomes. Under **Attach predictor
measurements**, upload a CSV with `observation_id` plus one or two numeric predictor
columns, declare their units and source, and review the matched IDs before attaching.
Missing predictors and mismatched IDs are rejected; fitting never silently drops
missing outcomes. This first implementation supports 6–500 independent measurements.

Ask chat to prepare a regression with one baseline predictor. Its real
`draft_regression` tool fills the controls and shows prior predictions. Review the
starting values, confirm independent measurement units, and fit. The app shows
coefficient intervals, uncertain measurement noise, outcome predictions, residual
patterns (including against an omitted predictor) and joint predictive checks.
Simulation intervals distinguish a borderline check from a clear mismatch flag;
increase the replicate count under **Adjust regression priors** when useful.

Retain the baseline review, including **Neither is adequate** when appropriate.
Then ask chat to add the second predictor while keeping the shared priors. Review
the expanded prior and fit both models on the same rows. Exact leave-one-out
refits compare predictive log scores, with a paired standard error and pointwise
differences. Retain the selected model and scientific reason; earlier reviews
remain inspectable. Independence already confirmed for these outcome measurements
can carry forward, and the checkbox remains editable.

The model has independent normal measurement errors with unknown common variance,
a proper inverse-gamma variance prior, and normal coefficient priors conditional
on that shared variance. Consequently, coefficients are marginally dependent.
Predictor midranges and half-ranges provide recorded default coding; the R API
also accepts explicit reference values and meaningful changes. No outcome values
are used to choose transforms or prior defaults. This is a new prior specification,
not an automatic conversion of earlier fixed-noise judgments or model extensions.

The R workflow is `regression_predictors()` → `record_predictors()` →
`regression_prior()` → `fit_regression()` → `record_regression()`. Use
`plot_regression()` for editable plots and `predict_regression()` for new cases
in the original predictor units. New-case mean and outcome intervals are marginal;
outside-range flags do not certify joint interpolation support. Prediction calls
do not observe outcomes or freeze a prospective test.

Run `Rscript dev/regression-acceptance.R` for a complete synthetic revision loop.
Fitting and leave-one-out calculations are exact; only predictive checks use
simulation. Model comparison after inspecting data is exploratory and subject to
model-search selection effects. Better prediction does not establish causality,
adequate fit, or model truth. Hierarchical models, interactions, arbitrary formulas,
general samplers, regression-specific power sensitivity and prospective-test
commitments remain outside this increment.

## Model-guided research

After retaining a regression model, ask chat to compare feasible next measurements.
**Plan the next measurement** (`/design`) reviews two target protocols and candidate
experiments. Each candidate is an alternative setting with independent replicates.
Choose estimation of the mean difference or a decision between the protocols.

The optional alloptr package must provide `bed_normal_contrast()`. This exact
normal/inverse-gamma calculation integrates unknown noise and uses squared-error
loss for estimation or an explicit linear utility preference for decisions. It
does not train Action-BED policies. Candidate experiment costs use the selected
loss units; zero omits costs under the unit budget. The practical usefulness of
an outcome does not automatically establish an economic utility threshold.

Chat prepares a preview. The person reviews feasibility, independent replication,
preferences, costs and inherited model checks before retaining a planning choice.
A saved plan is not an executed campaign or a frozen prospective test. See
[method evidence](artifacts/bed-implementation-evidence.md) and the
[research backlog](BACKLOG.md#sup-029).

## Inspect additional expectations

In **Record → Record an expectation**, retain a plausible range, explicit
quantiles, a comparison with a named reference condition, or an expected shape
between two conditions. Review the original wording and interpretation before
saving. These answers remain unfitted unless a supported fitting method uses
them; adding one preserves the earlier candidate and acceptance history.

**Inspect expectations beyond the anchors** compares the answers with a
straight-line projection only after you explicitly choose that additional
assumption. Mean uncertainty and future-batch variation are separate. A peak
expectation remains visible as a limitation of the straight-line model.

```r
x <- suppose_example()
j <- judgment(160, kind = "comparison", reference_condition = 140,
  units = "MPa", author = "Scientist",
  answer = "I expect a higher mean at 160, but have not stated a probability")
x <- record_judgment(x, j, "Retain a comparison for inspection")
check_expectations(x, linear = TRUE)

other <- claim("The gain warrants evaluating the additional cost", "Scientist")
x <- record_model_reference(x, other, x$revisions[[3]]$candidate$id,
  author = "Scientist", reason = "An implication to investigate; cost is not modeled")
```

Claim/prior references preserve independent wording and can be many-to-many.
They do not assert that a model was fitted to the linked claim or that the claim
is supported. `suppose inspect --json` includes the retained judgments and model
references. See the [P0 acceptance report](artifacts/p0-review.md) for reproducible
checks and the still-open intended-user walkthrough.
