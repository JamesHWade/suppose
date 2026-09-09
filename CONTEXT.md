# Suppose

Proposed vocabulary for discussing a workbench in which people express beliefs, explore their consequences, and revise them through evidence. Scientific and engineering inquiry is the initial focus, with a path to operational, product, and strategic decisions.

## Language

**Claim**:
A statement about a system within a specified scope and, where material, period. It may begin informally and need further clarification before it can be tested.

**Testable claim**:
A claim with defined observables, scope, and a stated relationship or event that evidence can challenge under an explicit assessment rule. A claim can be testable in principle while the available observations or interventions cannot distinguish it from an alternative.
_Avoid_: Proven claim, verified belief

**Hypothesis**:
A claim provisionally taken as a subject of investigation. It need not have a dedicated model or an assigned probability.
_Avoid_: Model, mechanism

**Belief**:
A person's or team's judgment about a claim or model, recorded with its rationale and any explicitly elicited uncertainty. A belief need not have a numerical probability.
_Avoid_: Observation, fact

**Assumption**:
A condition taken as given for a particular prediction or assessment, whose failure may change the interpretation of the result. The same statement may be treated as an assumption in one assessment and investigated as a hypothesis in another.

**Target quantity**:
The precisely defined property a claim concerns, such as a difference in mean strength, a purchase rate in a specified cohort, or an event's occurrence by a deadline. It distinguishes the question from the individual measurements or records used to assess it.

**Model**:
A mathematical or computational representation that connects assumptions and conditions to predicted observables or consequences. Multiple models may express different explanations of the same claim.

**Prior**:
A probability distribution over unknown quantities in a specified model, representing information before incorporating the designated observations through that model's likelihood. Its information basis and attribution remain explicit.
_Avoid_: Hypothesis, universal confidence score

**Prior elicitation**:
A process for translating domain judgments into candidate prior distributions under a stated model, then checking their correspondence with the intended judgments. It can use expectations about observable outcomes as well as model quantities.
_Avoid_: Empirical validation

**Prior predictive distribution**:
The distribution of possible observations implied by a model and its prior, before conditioning on the designated observations. It combines uncertainty about the model's unknown quantities with the outcome variation the model represents.

**Simulator**:
An executable realization of a model that produces outcomes under specified conditions and parameters. Its outputs describe consequences of that model.
_Avoid_: Independent observation of the target system

**Simulation run**:
A recorded execution of a simulator at identified conditions and parameters. It can provide evidence about the simulator's behavior; using it as evidence about an external system requires an explicit justification connecting the model to that system.

**Surrogate**:
A model used to approximate a more expensive response or simulator, with a declared domain and uncertainty representation.
_Avoid_: Mechanism, claim

**Prediction**:
A stated expectation for an observable under specified conditions, including applicable uncertainty and the reasoning or model revision that produced it. A prediction can be elicited directly before a complete model exists.
_Avoid_: Measurement

**Forecast**:
A prediction about an observable outcome or event over a defined future horizon. Assessing it does not require control over the event.

**Scenario**:
A specified set of conditions used to examine their consequences through a model. A scenario does not inherently carry a probability of occurring.
_Avoid_: Forecast probability

**Observation**:
A recorded measurement of the system under investigation, retaining the actual conditions, protocol, and measurement provenance. For a computational system, measurements can include outputs and performance recorded from its execution.
_Avoid_: Synthetic observation, belief

**Evidence item**:
An identified observation, source record, or other information considered in an assessment, with its origin, timing, and limitations retained. Its supporting or challenging role depends on the particular claim and assessment.

**Predictive check**:
A comparison between the outcomes implied by a model and relevant reference information. A check against elicited expectations examines the formalization; a check against independent observations examines its empirical adequacy.

**Sensitivity check**:
An examination of how a stated result changes under specified changes to priors, likelihoods, or other assumptions. Its scope is limited to the changes actually considered.
_Avoid_: Proof of robustness to every alternative

**Test commitment**:
A recorded set of claim revisions, predictions, observation or intervention conditions, horizon, assessment rules, and applicable model revisions fixed before examining the designated test outcomes. Later changes create a new revision and preserve the original commitment.

**Evidence role**:
The declared use of information relative to a particular assessment, such as forming a claim, fitting a model, or testing a prediction. Information used to construct a claim cannot also be presented as an independent prospective test of that same claim revision.

**Assessment rule**:
A declared procedure for comparing evidence with a claim or model's predictions, including how uncertainty, practical tolerances, missing outcomes, and inconclusive results are handled.
_Avoid_: Truth score

**Assessment**:
A result of applying a stated assessment rule to identified claim, prediction, evidence, and applicable model revisions. It can be inconclusive or indicate that every considered model is inadequate.

**Decision case**:
A question about what to do that connects available options to relevant claims, expected consequences, decision criteria, and unresolved uncertainties. Several cases can depend on the same claim.
_Avoid_: Hypothesis, truth assessment

**Option**:
A course of action under consideration in a decision case, including deferring or retaining the current course where applicable.

**Decision criterion**:
An explicit consideration used to compare options, such as service reliability, feasibility, cost, or time. Its assessment and rationale remain visible, including whether it reflects evidence, a preference, or a constraint.

**Preference**:
A person's or group's stated judgment about the desirability of outcomes. It is distinct from an empirical claim about which outcomes will occur.

**Decision**:
A recorded choice among options under identified evidence, criteria, and constraints. Choosing an option does not establish the truth of the claims informing it.

**Decision dependency**:
A stated connection identifying how a claim or assumption affects the comparison of options. It does not by itself establish a causal relationship or statistical independence.

**Review trigger**:
A specified change, observation, or date that calls for revisiting a claim assessment or decision. Missing expected evidence can trigger review without establishing that the claim is false.

**Campaign**:
A sequence of planned and executed experiments with a shared experimental space, purpose, resource budget, and accumulating record.

**Model discrimination**:
The use of measurements to distinguish competing models by their observable predictions.
_Avoid_: Outcome optimization

**Revision**:
A recorded change to a claim, belief, assumption, model, or assessment rule that preserves what was stated before the change and why it changed.

**Accepted record**:
A record reviewed and retained for subsequent use. Acceptance records an explicit knowledge-management decision and does not establish scientific truth.
