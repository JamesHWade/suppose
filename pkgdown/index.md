# Suppose

<div class="suppose-hero">
<p class="suppose-eyebrow">An R package for scientific inquiry</p>
<h2>Make beliefs explicit.<br>Explore what follows.</h2>
<p class="suppose-lead">Start with a question. Put your expectations into words and models.
Keep the evidence—and your reasons for changing your mind—in view.</p>
<p class="suppose-actions"><a class="btn btn-primary" href="articles/suppose.html">Get started</a>
<a class="suppose-secondary" href="articles/workbench.html">Explore the workbench →</a></p>
</div>

<div class="suppose-paths">
<section><span class="suppose-step">01 / EXPRESS</span><h2>Begin in your own words</h2>
<p>A belief can be incomplete. Clarify its meaning, assumptions, and open questions before choosing a model.</p>
<a href="articles/suppose.html">Start an inquiry →</a></section>
<section><span class="suppose-step">02 / INSPECT</span><h2>See what you are assuming</h2>
<p>Turn judgments into predictions. Separate uncertainty about a mean from the variation in a future measurement.</p>
<a href="articles/prior-consequences.html">Explore prior consequences →</a></section>
<section><span class="suppose-step">03 / REVISE</span><h2>Learn without losing the trail</h2>
<p>Bring in observations, check a model, and retain a reviewed revision alongside what came before.</p>
<a href="articles/regression.html">Fit and revise a model →</a></section>
</div>

## A small beginning

A useful inquiry does not require a fitted model or an AI account.

```r
library(suppose)

belief <- claim(
  "A longer cure may make this coating more durable.",
  author = "Researcher",
  unresolved = "Does the improvement justify the extra time?"
)
record <- elicitation_record(belief)
```

[Continue with a revision and a portable record](articles/suppose.html),
or use `suppose_app()` to develop the inquiry in conversation.

## Follow a worked example

| Your next question | Guide |
|---|---|
| What do my intervals imply about a difference? | [Inspect prior consequences](articles/prior-consequences.html) |
| How do measurements change the picture? | [Update a model with PlantGrowth](articles/measurements.html) |
| What is my first model missing? | [Fit, check, and revise a regression](articles/regression.html) |
| Which next measurement would be useful? | [Compare research designs](articles/research-design.html) |

Examples label invented judgments and retrospective data explicitly. Code in the
first three guides runs during the site build.

## Install the development version

Suppose is experimental and is not on CRAN. With access to its private repository
and GitHub authentication configured:

```r
pak::pak(c("JamesHWade/suppose", "ggplot2"), dependencies = NA)
```

[Workbench setup](articles/workbench.html#installation) covers the optional UI
and model-provider dependencies. Numerical and record operations work without
an AI account.

<div class="suppose-principle">
<h2>A reviewed belief is a starting point</h2>
<p>Acceptance records a person's review. Predictions describe a model's consequences.
Neither establishes scientific truth. <a href="articles/methods.html">Read the methods and limits</a>.</p>
<p class="suppose-status">Development version · Intended-scientist acceptance remains open.</p>
</div>
