# Elicited and visualized priors

Three new fictional conversations were run through the live Muse/Deputy chat.
Each begins without numeric prior inputs; the model asks for central 90% intervals
for the true means and distinguishes those from individual measurement variation.
The supplied intervals, correlation, measurement SDs and normal assumptions are
invented for these examples. No new observations were imported and no draft was
applied or accepted.

| Example | Conditions | Elicited central 90% mean intervals | Correlation | Known measurement SDs | Threshold | Prior probability above threshold |
|---|---|---|---|---|---|---|
| Adhesive dwell | 10 vs 20 minutes | 18–22 vs 21–27 MPa | 0.5 | 2, 2 MPa | 2 MPa | 89.3% |
| Mixing speed | 200 vs 400 rpm | 18–26 vs 17–27 g | 0 | 3, 3 g | 2 g | 30.4% |
| Enzyme incubation | 24 vs 48 hours | 20–24 vs 28–36 U/mL | 0.25 | 5, 5 U/mL | 5 U/mL | 98.0% |

Open the conversations:
- [Adhesive dwell](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a080dd066226e968e956)
- [Mixing speed](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a080de30bde6a7a84e7c)
- [Enzyme incubation](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a080deadb681fb802d0f)

The inline Review an interpretation card contains two charts: the marginal
normal priors for the means, with central 90% shading, and the implied contrast
compared with two future measurements. The latter includes measurement noise.
The Record panel also shows the plots. Plot data are retained as analytic
parameters and summaries; reopening does not refit or resimulate anything.
Charts include descriptive alt text and recompute layout at narrow widths.

These examples exposed several gaps, which were addressed: chat previously had
summaries but no plot; elicitation instructions were passive; mean intervals
should not be steered to a desired result; correlation can be negative; and
numeric templates should fill the composer instead of auto-submitting unknown
values. Prompt refinements guide those behaviors; model compliance is not a
hard guarantee. Historical responses and failed attempts remain visible.
The model recovered from scope and source-quotation tool errors before each
successful preview. One mixing turn contains an unintended suggestion submitted
during browser automation; the explicit numeric judgments were then sent using
the Send button. No transcript was rewritten.

All three stored priors and chart inputs matched the final proposals, and the
probabilities matched independent analytic calculations. All three plots and
pending review states restored after a process restart. The six conversations
remain separate. The original three lab examples were not edited.

Validation: 443 tests passed; R CMD check had zero errors, warnings and notes;
Air/Jarl checks passed and pkgdown built. See prior-final-check.log,
prior-examples-audit.json, prior-examples-audit.log and audit-prior-examples.R.
Standalone plots: prior-adhesive.png, prior-mixing.png, prior-enzyme.png.
