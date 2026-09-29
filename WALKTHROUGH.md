# Live conversational walkthrough

Follow-up implementation and adversarial review: [QUALITY-REVIEW.md](dev/notes/QUALITY-REVIEW.md).
The observations below describe the earlier version and are retained as replay cases.

September 7, 2026 (America/Detroit). Five completed live Muse responses across
two separate browser sessions at port 3895, using the current Deputy/shinychat
integration. These were agent-driven examples, not a domain-user acceptance
session or evidence about a real team or market. Existing user sessions were
left alone. No application code changed during this walkthrough.

## What the app does in practice

The assistant discusses a question and uses `propose_interpretation` to produce
a separate draft. The Record footer signals that the draft is ready. Its drawer
shows current wording, proposed fields, the reason for changes, source words,
and explicit Apply/Decline controls. A fluent response and a source quotation
do not guarantee that the structured interpretation preserves meaning.

Both final proposals were left unapplied for inspection. Saving/reopening and
semantic acceptance were not repeated in this walkthrough; prior integration
checks are documented in ACCEPTANCE.md.

## Example 1: meeting frequency and coordination

First input:

> I think fewer team check-ins and one-on-ones would free up focus time and help us achieve our objectives sooner over the next quarter. But I worry that coordination could get worse. I don’t know what reduced efficiency would look like. Can you help me think this through?

The assistant drafted an interpretation, then enumerated question, belief,
expectations, assumptions, and observation. It called not knowing how to define
reduced efficiency an observation, and asked what worse coordination would
look like. That asks the person to supply the very thing they need help with.

Second input:

> That is the part I don’t know how to define. Please suggest a few concrete things I could notice, and help me choose a small next step. Also, not knowing how to define it is an open question, not an observation about the team.

The assistant corrected the distinction, offered duplicated work, waiting on
decisions/inputs, and slipping handoffs as possible signs, and suggested a
limited two-week trial of dropping or shortening one meeting. It asked which
sign would be easiest to notice. These were suggestions, not reported events.

The inspected proposal retained the original quarter horizon and placed the
undefined coordination effects under Open questions. It did not promote the
assistant's suggested trial into an agreed plan. This was a useful recovery,
but required explicit steering toward concrete help.

An additional scope-correction submission was rejected by automatic approval
review over potentially sensitive workplace content going to OpenRouter. It
was not retried and is not counted as an executed turn.

## Example 2: demand for migration help

First input:

> I think small software teams would pay for someone to handle their database migrations. Two friends said it sounded useful. I’m tempted to build a service, but what should I actually learn before committing?

The assistant distinguished friendly encouragement from willingness to pay,
identified alternative explanations, and asked which teams were intended.

Second input:

> Teams of five to twenty engineers running PostgreSQL, without a dedicated database specialist. I can talk to three teams next week. What should I ask or offer that would teach me more than whether they like the idea? Please give me a useful first step, not just another question.

The assistant suggested asking about a recent difficult migration, its cost,
what changed afterward, and who decides to buy help. It proposed a free plan
review/debrief as a small observable next step. This could reveal access and
pain, but would not itself establish willingness to pay.

Third input:

> Let’s narrow the offer to a paid review of an upcoming migration plan, not handling the migration itself. I have not offered or sold this yet. If three teams say yes in interviews, would that establish demand? Please update the draft and suggest what evidence would be stronger.

The assistant correctly said three interview yeses would not establish demand
and suggested stronger commitments: a real upcoming migration, sharing the
plan, access to the buyer, and a paid slot/deposit. The proposed record changed
the offer to paid review and retained the specified team scope.

However, both the reply and the proposal's Expectations field changed the
conditional question into **“Three teams say yes in interviews.”** The source
words still contain **“If three teams say yes in interviews, would that establish
demand?”** This is an observed loss of meaning, not merely awkward presentation.

The draft also lists assumptions such as interview agreement predicting payment.
Those are useful candidate assumptions to investigate, but the person did not
endorse them. Their status needs to be explicit when reviewing the record.

## Findings and follow-up acceptance cases

1. **Preserve conditional meaning.** A hypothetical outcome must not become an
   elicited expectation. Re-run the exact third product input and inspect both
   chat and structured fields; neither may assert an expected count of yeses.
2. **Help when the person cannot define something.** Offer a few possible
   observable signs, explain their relevance, and invite correction. Do not
   merely repeat the unresolved question. The meeting example should reach
   useful concrete help without the second input explicitly demanding it.
3. **Keep categories mostly in the record.** All five replies leaned on explicit
   epistemic labels. Their distinctions matter, but repeated taxonomy makes
   the conversation feel like form completion. Evaluate naturalness alongside
   faithful classification; do not remove the underlying distinctions.
4. **Avoid irrelevant implementation explanations.** The last product reply
   explained the two-condition normal model's interval/SD requirements although
   the person had not requested numerical analysis. Mention that boundary when
   it affects a requested action.
5. **Render missing units clearly.** Both inspected proposals displayed literal
   `null` under Units. Inspect the generated field and rendering path before
   deciding whether this is model serialization, validation, or presentation.
6. **Distinguish proposed assumptions from user commitments.** A useful
   assumption to test is not automatically a belief held by the person.

The current system is useful for organizing and correcting an inquiry and can
offer practical next steps. It still requires attentive review of meaning.
The next bounded increment should address these conversation and interpretation
failures before treating this walkthrough as first-session acceptance.

The prompt in `R/inquiry.R` asks for one question at a time and explicit
distinctions among epistemic categories, and describes the numerical boundary.
That is a plausible contributor to the response style, not a demonstrated
causal diagnosis; a before/after replay is needed to evaluate a prompt change.
