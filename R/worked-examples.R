worked_examples <- function() {
  list(
    meetings = list(
      title = "1. Turn a hunch into a question",
      description = "Clarify a workplace belief, preserve the original words, and decide what would challenge it. No numerical model needed.",
      provenance = "Fictional workplace scenario; no measured outcomes.",
      steps = c(
        "Open Record and read Retained interpretation. The original hunch became a question about task completion time for one team over four weeks; meeting count and coordination quality remain open questions.",
        "Open History and conversation and inspect the two revisions. The first wording is preserved. A clearer question is not evidence that fewer meetings will help.",
        "Try it: open Edit the interpretation yourself, change the target or scope, explain your reason, and retain the revision. Then use Review and accept to state what could change your mind. Your review is separate from the tutorial setup.",
        "Check your understanding: what would you measure, and what alternative explanation could make the apparent effect misleading? Save conversation and record to keep your changes."
      )
    ),
    strength = list(
      title = "2. Explore beliefs through possible outcomes",
      description = "Compare independent and correlated prior beliefs, then step through plausible means and future measurements.",
      provenance = "Invented strength judgments; no observed data.",
      steps = c(
        "Open Record > Optional model and its consequences > Possible outcomes. Use Next realization and Previous realization to inspect the two means, two future measurements, and their differences together.",
        "Read the probability dots and exact probability of a mean improvement greater than 5 MPa. Each dot represents 1% of a distribution. One future measurement at each condition has more uncertainty than the mean contrast.",
        "Open History and conversation and compare the two numerical revisions: independent means first, correlation 0.8 second. Marginal intervals are unchanged, but shared uncertainty changes the contrast probability. Return to the latest revision before editing.",
        "Check your understanding: why can the two means move together while their difference stays comparatively stable? Why can a future measurement contrast miss 5 MPa even when the mean contrast exceeds it? These draws express beliefs, not evidence."
      )
    ),
    plants = list(
      title = "3. Learn from measurements",
      description = "Follow a PlantGrowth update from prior to posterior, then inspect sensitivity to prior and likelihood strength.",
      provenance = "Public R PlantGrowth measurements. Retrospective analysis with an illustrative prior and fixed measurement SD of 0.6 weight units.",
      steps = c(
        "Open Record > Measured observations to inspect the control and treatment-2 outcomes and their source. The dataset's physical weight units are not specified; this example uses weight units. These outcomes were already available when the tutorial prior was chosen.",
        "Open Learn from measurements > Update of revision 2. Compare the prior and posterior for treatment 2 minus control and read the probability of exceeding 0.5 weight units. The update assumes independent normal measurements with SD fixed at 0.6; it does not estimate that SD.",
        "Open Check sensitivity and expand the retained Sensitivity result. Inspect how the mean estimate and threshold probability change when prior strength or likelihood weight changes. This does not check every possible model assumption.",
        "Try it: preview another sensitivity comparison with a different change threshold. Explain what change would matter scientifically before retaining it. These explored outcomes cannot become an independent prospective test by relabeling them."
      )
    ),
    regression = list(
      title = "4. Find what a model misses",
      description = "Inspect a temperature-only model, add duration, and compare predictive performance on the same synthetic measurements.",
      provenance = "40 synthetic preparations with a deliberately constructed duration effect. Tutorial reviews are attributed to the Tutorial analyst, not to you.",
      steps = c(
        "Open Record > Measured observations for the synthetic outcomes, then Fit and compare models. Expand the first Reviewed regression (neither): the temperature-only model misses the duration effect built into these data.",
        "Expand the second Reviewed regression (extended). Compare its residual patterns, predictive checks, and leave-one-out score with the baseline. Both models use the same rows. A positive extended-minus-baseline score favors the extended model's held-out prediction, but does not prove it adequate.",
        "This regression uses an explicit normal/inverse-gamma prior and estimates a common noise variance. It does not silently convert the two-condition elicitation into regression coefficients.",
        "Try it: inspect Adjust regression priors, preview the prior consequences, then fit and check before recording your own review. Explain which residual pattern matters, rather than choosing a model from its score alone. These synthetic data provide no evidence about a real coating."
      )
    )
  )
}

#' Open a worked learning record
#'
#' These records include a guided conversation and attributed tutorial setup.
#' They can be explored without a model provider using [suppose_app()].
#' Meetings and strength are fictional; plants uses public `datasets::PlantGrowth`
#' outcomes retrospectively with an illustrative prior and fixed measurement SD.
#' Regression uses synthetic data with a deliberately omitted predictor.
#' Tutorial reviews are not the user's acceptance. Save changes with [write_record()].
#' @param example One of `"meetings"`, `"strength"`, `"plants"`, or `"regression"`.
#' @param seed Nonnegative integer simulation seed.
#' @return A validated `suppose_record` with a guided conversation.
#' @export
#' @examples
#' record <- suppose_worked_example("meetings")
#' if (interactive()) suppose_app(record)
suppose_worked_example <- function(
  example = c("meetings", "strength", "plants", "regression"),
  seed = 47L
) {
  example <- match.arg(example)
  check_count(seed, "seed", 0, .Machine$integer.max)
  out <- switch(
    example,
    meetings = worked_meetings(),
    strength = suppose_example(seed),
    plants = worked_plants(seed),
    regression = worked_regression(seed)
  )
  lesson <- worked_examples()[[example]]
  text <- paste0(
    "## ",
    lesson$title,
    "\n\n",
    lesson$provenance,
    "\n\nThis is your own example copy. Explore and edit it; other sessions are unchanged. Use Save conversation and record to keep your changes before closing.\n\n",
    paste(
      paste0(seq_along(lesson$steps), ". ", lesson$steps),
      collapse = "\n\n"
    )
  )
  record_conversation(
    out,
    list(list(
      role = "assistant",
      text = text,
      status = "complete",
      created_at = now_utc()
    ))
  )
}

worked_meetings <- function() {
  original <- claim(
    "Fewer recurring meetings might help our team finish work sooner.",
    "Tutorial analyst"
  )
  revised <- revise_claim(
    original,
    "Tutorial analyst",
    "Define an observable outcome and a bounded comparison",
    target = "Time from starting a task to completing it, comparing weeks with fewer recurring meetings against usual practice",
    units = "days",
    scope = "One team; comparable task types",
    horizon = "Next four weeks",
    expectations = "Less meeting time may leave more uninterrupted work time",
    assumptions = "Coordination remains effective and task difficulty is comparable",
    unresolved = c(
      "Which meetings are useful?",
      "How will task difficulty and staffing changes be accounted for?",
      "What change in completion time would matter?"
    )
  )
  record_revision(
    elicitation_record(original, "Fewer meetings, clearer question"),
    revised,
    reason = "Keep the original hunch while making the question inspectable"
  )
}

worked_plants <- function(seed) {
  belief <- claim(
    "Does treatment 2 increase mean dried weight by more than 0.5 weight units?",
    "Tutorial analyst",
    target = "Mean dried weight for trt2 minus ctrl",
    units = "weight units",
    threshold = 0.5,
    scope = "PlantGrowth; group codes 0 = ctrl and 1 = trt2",
    assumptions = "Independent normal measurements; SD fixed at 0.6 for illustration",
    unresolved = "Retrospective example; independence and causal meaning need justification"
  )
  judgments <- lapply(0:1, function(condition) {
    judgment(
      condition,
      c(4, 6),
      c(0.05, 0.95),
      units = "weight units",
      condition_units = "group code",
      author = "Tutorial analyst",
      answer = "Illustrative central 90% interval for the population mean: [4, 6]",
      source = "Analyst-selected tutorial prior",
      observed = "Public PlantGrowth outcomes already available"
    )
  })
  prior <- fit_prior(belief, judgments, correlation = 0, batch_sd = c(0.6, 0.6))
  out <- record_revision(
    elicitation_record(belief, "PlantGrowth retrospective update"),
    belief,
    prior,
    predict_prior(prior, seed = seed),
    reason = "Illustrative retrospective prior, not prospectively elicited"
  )
  plants <- datasets::PlantGrowth[
    datasets::PlantGrowth$group %in% c("ctrl", "trt2"),
  ]
  ids <- paste0("plant-", seq_len(nrow(plants)))
  observations <- import_observations(
    data.frame(
      observation_id = ids,
      condition = as.character(plants$group),
      outcome = plants$weight,
      batch = ids,
      specimen = ids,
      observed_at = "unknown"
    ),
    source = "R datasets::PlantGrowth; ctrl and trt2",
    protocol = "Published dried plant weights; independence assumed for tutorial",
    author = "Tutorial analyst",
    units = "weight units",
    role = "update",
    exposure = "explored"
  )
  out <- record_observations(
    out,
    observations,
    reason = "Retain public outcomes with prior exposure declared"
  )
  updated <- update_prior(
    prior,
    observations,
    condition_map = c(ctrl = 0, trt2 = 1),
    independent = TRUE
  )
  out <- record_update(
    out,
    updated,
    reason = "Retrospective update under fixed SD assumptions"
  )
  sensitivity <- sensitivity_analysis(
    out,
    out$updates[[1]]$id,
    quantities = c("estimate", "probability"),
    estimate_change = 0.1,
    probability_change = 0.05
  )
  record_sensitivity(
    out,
    sensitivity,
    "Tutorial comparison of prior and likelihood strength"
  )
}

worked_regression <- function(seed) {
  temperature <- rep(c(140, 150, 160, 150), length.out = 40)
  duration <- rep(c(50, 50, 70, 70, 60), length.out = 40)
  strength <- 54 +
    0.4 * (temperature - 150) +
    1.8 * (duration - 60) +
    rep(c(-1, 1, -2, 2, 0), length.out = 40)
  ids <- paste0("preparation-", seq_along(strength))
  observations <- import_observations(
    data.frame(
      observation_id = ids,
      condition = as.character(temperature),
      outcome = strength,
      batch = ids,
      specimen = ids,
      observed_at = "unknown"
    ),
    source = "synthetic:worked-example",
    protocol = "Invented independent preparations",
    author = "Tutorial analyst",
    units = "MPa",
    role = "update",
    exposure = "explored"
  )
  out <- record_observations(
    suppose_example(seed),
    observations,
    "Inspect the synthetic measurements"
  )
  predictors <- regression_predictors(
    out,
    out$observations[[1]]$id,
    data.frame(observation_id = ids, temperature, duration),
    units = c(temperature = "degC", duration = "minutes"),
    source = "synthetic:worked-example-predictors",
    author = "Tutorial analyst"
  )
  out <- record_predictors(out, predictors)
  for (terms in list("temperature", c("temperature", "duration"))) {
    prior <- regression_prior(
      out,
      predictors$id,
      terms,
      location = 54,
      intercept_sd = 10,
      effect_sd = 20,
      noise_sd = 3
    )
    fit <- fit_regression(
      out,
      prior,
      independent = TRUE,
      reviewed = TRUE,
      seed = seed
    )
    extended <- length(terms) == 2L
    out <- record_regression(
      out,
      fit,
      choice = if (extended) "extended" else "neither",
      author = "Tutorial analyst",
      reason = if (extended) {
        "Duration addresses the constructed omission; this is an exploratory synthetic example."
      } else {
        "The temperature-only model misses the constructed duration effect."
      },
      reviewed = TRUE
    )
  }
  out
}

worked_examples_ui <- function() {
  shiny::tagList(
    shiny::p(
      "Choose a worked record with a guided walkthrough. Each opens in a new tab, leaving this conversation in place. No model provider is required."
    ),
    lapply(names(worked_examples()), function(id) {
      lesson <- worked_examples()[[id]]
      shiny::tags$section(
        class = "worked-example-card",
        shiny::tags$h3(lesson$title),
        shiny::p(lesson$description),
        shiny::p(class = "hint", lesson$provenance),
        shiny::tags$a(
          class = "btn btn-outline-primary",
          href = paste0("?suppose_example=", id),
          target = "_blank",
          rel = "noopener",
          paste(
            "Open example",
            match(id, names(worked_examples())),
            "in new tab"
          )
        )
      )
    })
  )
}

worked_example_session <- function(search, record, history_dir) {
  query <- shiny::parseQueryString(search %||% "")
  id <- query$suppose_example
  if (is.null(id) || !id %in% names(worked_examples())) {
    return(list(record = record, history_dir = history_dir))
  }
  list(record = suppose_worked_example(id), history_dir = NULL)
}
