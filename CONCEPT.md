# Suppose: working concept

Working product proposal for discussion. This document sharpens the intended experience and scientific meaning before implementation planning.

The proposed promise is: **Make beliefs explicit, explore their consequences, and identify what evidence would change your understanding or decisions.**

The initial value should be available before the user collects new data. Someone should be able to recognize, correct, and challenge the formal expression of their belief during the first session. Experiment design becomes more useful once that expression is meaningful.

The entry point is a conversation about a problem, belief, or decision. It should
work naturally for research, engineering, operations, product development,
customer behavior, or an everyday question. The user's domain supplies the
vocabulary, quantities, scope and evidence needs. A laboratory form must not
define the product's interface.

A general conversation does not imply that every analytical method exists. The
workbench can retain and review an interpretation before there is an executable
model. An assistant proposes a supported method only when it fits the question,
and leaves unsupported analyses explicit. The current two-condition normal model
is one optional method and worked example.

shinychat presents the conversation and tool activity. A Deputy Agent owns model
execution, tool governance, usage limits and cancellation. Suppose owns the inquiry
record, statistical procedures, proposal review and acceptance. Model providers
remain behind the Agent's ellmer client.

**What the user makes**

The durable artifact connects a claim in the user's own words to a precise target quantity or observable event, its scope and time horizon, plausible outcomes, supporting assumptions, optional executable models, and an account of what evidence would change the assessment. Unresolved questions remain visible. It can start with a partial formalization.

A single claim can be represented by several models, and a single model can have implications for several claims. Competing models are useful when they represent meaningful alternatives, but are not required for every claim. A directly elicited prediction or a threshold claim may already be worth inspecting and testing.

The user retains the original wording alongside each formal revision. The important acceptance step is semantic: does this mathematical statement and its implied behavior express what the scientist intended? Correct syntax alone does not establish that correspondence.

Where a decision is involved, a decision case connects the available options to the claims on which they depend, expected consequences, explicit criteria, and unresolved questions. One decision can depend on several claims, and one claim can matter to several decisions. A growth opportunity is one possible kind of decision case; the broader vocabulary must also fit a research question, a reliability problem, or an operational change.

**One concrete example**

Start with the illustrative claim, “Higher cure temperature makes the material stronger.” This could refer to an average difference between two temperatures, a monotonic response across an interval, a causal effect of changing the process, or a particular mechanism. Those meanings require different evidence.

One possible refinement is: “For formulation F under protocol P and a fixed cure duration, changing the cure temperature from 140 degrees C to 160 degrees C increases mean tensile strength across independently prepared batches by at least 5 MPa.” The numbers illustrate a possible specification and are not empirical claims about a material.

The target quantity is the difference between those two population means. A monotonic relationship over the whole temperature range would be a separate claim. A causal interpretation would require an appropriate intervention or an explicitly justified identification strategy; prediction from historical associations alone does not establish it.

The scientist can state plausible strength ranges at selected temperatures, indicate where they expect a plateau or decline, and identify conditions under which the relationship might fail. The workbench exposes whether a range describes specimen-to-specimen variation, uncertainty in the mean, or some other judgment. A plausible range is not automatically a probability interval.

When a model is introduced, the scientist inspects the behavior it permits: outcome ranges, response shapes, limiting cases, and consequences of changing assumptions. A model that disagrees with the scientist's intended expectations calls for clarification or revision before a proposed experiment becomes authoritative.

**Prior elicitation as a central interaction**

Prior elicitation offers a concrete way to deliver that first-session value. The proposed interaction is to ask about quantities the person understands, construct candidate priors under an explicit model, and show their predictive consequences for correction. Mikkola and colleagues, including Aki Vehtari, identify usable elicitation tools and integration with the Bayesian workflow as outstanding needs in their [2024 review](https://doi.org/10.1214/23-BA1381).

For the material example, the scientist might describe plausible batch means at selected temperatures, variation between batches, and how surprising a decrease would be. The workbench clarifies the meaning and probability content of those judgments before attempting a numerical fit. It then displays simulated measurements and response curves, including behavior the elicitation questions did not directly constrain. The person can recognize a mismatch and revise either their judgment or its formalization. Qualitative judgments remain useful when numerical probabilities cannot be supplied responsibly.

A few elicited summaries may be compatible with several priors, particularly for dependencies among unknown quantities. The workbench should expose consequential alternatives and the choices needed to select among them. It retains the original answers, their sources, model assumptions, fitting procedure, discrepancies, and accepted revision. A close fit to elicited expectations establishes correspondence with those expectations; empirical adequacy needs observations of the target system. Information already represented in the elicited prior must not be counted again as independent evidence.

This suggests a first-session sequence: clarify the claim and scope, elicit observable expectations, construct candidate priors and predictions, inspect their consequences, and accept or revise the formalization. Simulation may enter during elicitation, before a detailed mechanistic simulator exists. Bockting and Bürkner's [elicito preprint (2025)](https://arxiv.org/abs/2506.16830) provides an adjacent software reference for simulation-based elicitation; Vehtari is not a coauthor of that paper.

Two later checks extend the loop. After fitting to observations, [priorsense](https://n-kall.github.io/priorsense/) can examine sensitivity to specified changes in prior and likelihood strength. When a model grows, Riha and colleagues' [June 2026 preprint on predictively consistent priors](https://arxiv.org/abs/2606.22850), coauthored by Vehtari, motivates inspecting how its prior predictions change. Our design inference is to make both changes visible to the person: a conclusion that depends heavily on a prior deserves examination, and adding variables should not silently change the substantive expectations the person accepted. Neither check certifies a model's truth or covers every alternative assumption.

A hypothesis and a prior remain different objects. For a defined service offer and horizon, a hypothesis might be that the population purchase probability exceeds 20%; a prior describes uncertainty about that probability under a stated model. An elicited prediction about purchases in a cohort also includes outcome variation. This distinction carries the same interaction beyond laboratory work.

**Two activities with a deliberate transition**

During exploration, the user can freely change claims, assumptions, models, and analyses while inspecting existing data. This activity should feel lightweight and productive.

For a prospective test, the user makes a test commitment that records the claim revision, model and data basis where applicable, predictions, observation or intervention protocol, horizon, and assessment rule before inspecting the designated outcomes. Changes remain possible, but create a new revision with their reason and evidence exposure retained. A frozen prediction alone does not establish the validity of the analysis or control its error rates.

Observations used to formulate a claim or fit a model can remain useful. Their role must be clear when the product assesses that claim. A result should state whether it is an exploratory fit, a model check, or a prospective evaluation rather than collapsing those into a single confidence score.

A forecast can be assessed when its defined horizon closes even if the user cannot control the event. An observational relationship can be useful without establishing the effect of an intervention. The workbench should state what kind of claim is being assessed and what the available evidence can establish.

**What a simulation contributes**

A simulator computes consequences of assumptions. It can expose contradictions, explore sensitivity, help choose measurements, or approximate an expensive system. A simulation run can itself be an experiment on a computational model. Its relationship to the external system under investigation remains an additional scientific claim.

Models can represent response curves, service queues, adoption, staffing, throughput, or unit economics. A scenario states what follows if selected conditions hold. A model can produce probabilistic predictions conditional on a scenario without assigning that scenario a probability. A forecast for the world as it unfolds also needs a stated treatment of uncertain future conditions. Shared drivers and dependencies must remain visible when several claims enter the same model.

Beliefs may inform soft priors or expected response shapes. Hard physical or operational restrictions have a different role. A disputed monotonicity claim should not be hard-coded into every admissible model and subsequently treated as supported by those models' agreement.

Outcome variability, uncertainty within a chosen model, and uncertainty about the model's adequacy should be distinguished when they affect an interpretation. The product should not present all three as one undifferentiated band of uncertainty or imply that a surrogate's variance captures every source of error.

**What makes a useful challenge**

The next useful action may be a clarifying question, checking an existing dataset, seeking a source, conducting an interview, observing a future event, measuring a nuisance variable, replicating a condition, running a simulator, or performing an experiment. These activities produce different kinds of evidence and should retain that distinction.

For experiments, the purpose must be explicit: estimate a target quantity, discriminate between explanations, detect model inadequacy, or improve an outcome. Recommendations should account for cost, feasibility, noise, and the decision the result can affect. Disagreement between two mean curves alone is insufficient to establish that a measurement will distinguish them.

If all available experiments imply effectively indistinguishable measurements, the appropriate result is an explanation of that limitation and what additional intervention or observable could help. Relative preference among candidate models should not conceal poor fit by all candidates.

When a decision is attached, the value of learning depends on whether it can improve that decision enough to justify its cost and delay. The largest uncertainty need not be the most useful one to reduce. Evidence strength, potential benefit, feasibility, investigation cost, and the consequence of being wrong should remain separately inspectable. Quantitative decision analysis is possible when its model and preferences have a defensible numerical basis; qualitative judgments remain legitimate when they do not.

**A path beyond laboratory work**

Consider an engineering team evaluating a paid migration service. A broad statement such as “Teams will pay for easier migration” conceals several distinct claims. Illustrative claims might be:

| Claim | Evidence that could challenge it | Role in a model |
|---|---|---|
| At least half of a defined customer segment currently spends more than two engineer-days on migration. | A suitably sampled study of actual migration effort and its distribution. | Size and severity of the customer problem. |
| At least 20% of eligible accounts offered the specified service at price P purchase within 60 days. | Offer and purchase records under a defined pilot and eligibility rule. | Adoption and revenue over the horizon. |
| Median delivery effort stays below six engineer-hours for completed migrations meeting the service standard. | Delivery records, rework, failures, and the completion rate. | Staffing and cost; the median alone does not determine total cost. |
| Support demand stays within a specified staffing limit during the first 90 days after migration. | Support workload and service outcomes for the enrolled cohort. | Continuing capacity and service quality. |

The thresholds are invented examples, not empirical findings or recommended business targets. The pilot's population and protocol determine what can be generalized beyond it. Interviews can help formulate a willingness-to-pay claim, while actual offer behavior tests a different and more specific proposition.

A model can connect adoption, delivery effort, support demand, and price to capacity and contribution. It can reveal that the proposed service is attractive only under a narrow assumption about delivery effort. The next useful step may therefore concern delivery rather than collecting more expressions of customer interest.

The same structure can support an equipment upgrade, a new product feature, a supplier qualification, or a research program. The user's question can move between “What do I believe?”, “What follows from that?”, and “Which uncertainty matters to this choice?” while retaining the same claim and evidence history.

**Learning from changes over time**

A later review experience should connect new evidence to existing beliefs and affected decisions: what was previously expected, what the new source or observation shows, which interpretation is proposed, and what action might change. A proposed interpretation remains distinct from the record a person chooses to accept.

The useful future briefing is a review of consequential changes. It should also be able to report that no decision-relevant change was found within the observed coverage. A failed source check, missing outcome, or incomplete observation period is not evidence that nothing changed. The source's publication date, event date, observation period, and the time of the assessment may differ.

Some revisions reflect a mistaken earlier belief; others reflect a changed population, operating regime, or external condition. Preserve the earlier scope rather than rewriting history. Several reports repeating the same underlying source should not be treated as independent confirmations. A report about an announced action is evidence of the announcement, with realized outcomes requiring their own evidence.

The longer-term view may contain several decision cases with shared claims, owners, deadlines, and dependencies. It should explain why one case needs attention and retain criteria and unknowns rather than invent a universal opportunity score. Reviewing accepted knowledge, choosing to investigate, and authorizing a consequential action are distinct decisions.

**The assistant's responsibility**

The assistant proposes interpretations, elicits missing information, translates approved meaning into candidate mathematics, retrieves relevant sources, and explains consequences. It makes assumptions and their origins inspectable. It can challenge inconsistencies between the user's words, elicited expectations, and model behavior.

The person investigating supplies the intended meaning and domain judgment. Deterministic computations and explicit statistical procedures produce numerical results. The assistant cannot obtain evidential authority from fluent explanation or generate the observations used to claim that a hypothesis about the system under investigation survived testing.

Different people may retain different beliefs about a shared claim. Their judgments should retain attribution and should only be pooled under an explicit method. Belief elicitation should allow ranges, ordering, shape restrictions, and qualitative judgments without forcing an invented numerical confidence.

Preferences also remain attributable. “We prefer predictable delivery over maximum throughput” expresses a decision preference. Empirical claims about delivery and throughput can be investigated; the preference is a declared value judgment. A person's choice to proceed under uncertainty does not turn the supporting claims into established facts.

**Relationship to the existing ecosystem**

The new domain concerns the meaning and revision of claims, their relation to models, and the evidence used to assess them. alloptr's campaign and numerical-design concepts fit the experimental portion of that domain. Graft fits reviewed history, Tempest fits source-grounded research, and ellmer/Deputy fit the assistant interaction and execution. This is a proposed division of responsibilities based on the prior repository inspection, not a claim that the complete workflow exists today.

The implementation follows tidyverse design principles and makes extensive use of usethis for package setup and maintenance, with r-lib tooling and cli for consistent development and console communication. The workbench uses Shiny/bslib and shinychat, connected to ellmer. A package CLI uses Rapp for argument parsing and r-lib's ir/rx for launch and installation. All surfaces call the same domain and statistical APIs. These are agreed implementation requirements; detailed contracts and dependency versions are resolved in the [backlog](BACKLOG.md).

The concept should remain understandable and useful when someone supplies their own model and existing measurements.

**Expansion direction**

Start with a bounded claim and an inspectable model in a scientific or engineering workflow. Extend the same experience to an operational or product question with observational data or a forecast. From there, connect multiple claims to a decision and explore scenarios. Repeated source review, change briefings, and portfolios of decisions belong further along that path.

The early concepts should already allow observations beyond experiments, claims with time horizons, optional decision context, and separate evidence, assessment, and action records. Broad monitoring, cross-domain portfolios, and automatic work routing belong later in the product's development.

**Product judgments proposed by this pass**

- The first payoff is recognizing and improving the formal expression of one's belief.
- Prior elicitation is a leading candidate for the central interaction: express expectations, inspect their simulated implications, and correct the formalization before collecting new evidence.
- Partial formalizations are useful; a complete simulator and two rival models are not entry requirements.
- The original claim and formal statement stay connected and independently inspectable.
- Exploration and prospective testing share a workspace while retaining distinct evidence histories.
- The product can conclude that a claim is insufficiently specified, untestable with available measurements, contradicted under a stated rule, or still unresolved.
- A numerical probability about a claim requires a stated model and inference basis. It is not an inherent field that every belief must contain.
- A helpful first-session outcome is a model or prediction the scientist recognizes as their own, one consequential assumption made visible, and a concrete way to challenge it.
- Decisions can connect several claims without collapsing their evidence, uncertainty, or criteria into one score.
- The longer-term path explicitly includes operational, product, and strategic settings, with evidence and time semantics that fit observation as well as intervention.
- Language, examples, and presentation remain organization-neutral.

The requested expansion beyond laboratory settings is part of the direction. The exact initial use case remains a proposal to refine before implementation planning. The present recommendation favors formalization and exploration, with decision context available when it helps explain why a claim matters.

The distinctive value to test is the traceable connection between scientific intent, mathematical consequences, and later revision. A fuller landscape review would be needed before claiming novelty over existing elicitation, modeling, preregistration, or experiment-design tools.

**Research anchors**

- [Mikkola et al., Prior knowledge elicitation: The past, present, and future](https://doi.org/10.1214/23-BA1381), Bayesian Analysis, 2024: Vehtari-coauthored review of elicitation methods, expert interaction, and workflow gaps; [open manuscript](https://arxiv.org/abs/2112.01380).
- [Kallioinen et al., priorsense: Efficient prior and likelihood sensitivity checks for Bayesian models in R](https://joss.theoj.org/papers/10.21105/joss.11036), July 2026: Vehtari-coauthored software paper. Sensitivity analysis complements elicitation after model fitting.
- [Riha et al., To select or not to select: predictively consistent priors instead of model selection](https://arxiv.org/abs/2606.22850), June 2026 preprint: examines stable prior predictive implications as model complexity increases. It does not establish that comparing scientific explanations is unnecessary.
- [Bockting and Bürkner, elicito: A Python Package for Expert Prior Elicitation](https://arxiv.org/abs/2506.16830), June 2025 preprint: modular simulation-based elicitation connecting domain judgments and model priors. An adjacent reference with different authorship.
- [Hartmann et al., Flexible Prior Elicitation via the Prior Predictive Distribution](https://proceedings.mlr.press/v124/hartmann20a.html): supports eliciting knowledge in terms of observable outcomes and connecting it to model priors. The suggested product interaction is our design inference.
- [Nosek et al., The preregistration revolution](https://doi.org/10.1073/pnas.1708274114): supports distinguishing prediction from explanations formed after observing outcomes. The proposed commitment mechanism is a product design choice and does not by itself establish statistical validity.
- [Catanach and Das, Metrics for Bayesian Optimal Experiment Design under Model Misspecification](https://arxiv.org/abs/2304.07949): motivates accounting for model discrepancy when judging the value of an experiment.
- [Stan User's Guide, Decision Analysis](https://mc-stan.org/docs/stan-users-guide/decision-analysis.html): distinguishes possible actions, predicted outcomes, and the utility assigned to those outcomes.
- [Heath and colleagues, Calculating the Expected Value of Sample Information in Practice](https://arxiv.org/abs/1905.12013): supports judging prospective research by its expected contribution to a decision. The proposed product prioritization is our design inference.
- [Hyndman and Athanasopoulos, Forecasting with regression](https://otexts.com/fpp3/forecasting-regression.html): explains scenario-based forecasting conditional on specified predictor values.
