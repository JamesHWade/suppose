# Explicitly fictional quality probes. Opt-in live inference through OpenRouter.
# Contributor prompts and outputs may be used by Meta for training.
pkgload::load_all(quiet = TRUE)
if (!nzchar(Sys.getenv("OPENROUTER_API_KEY"))) {
  stop("Configure OPENROUTER_API_KEY locally before running this live check.")
}
cases <- list(
  coordination = c(
    paste(
      "This is a wholly fictional example for testing the app, not information about a real organization.",
      "Imagine a volunteer theatre group. I think fewer planning meetings could free time for rehearsals, but coordination might suffer.",
      "I do not know what worse coordination would look like. Help me think this through."
    ),
    paste(
      "In this fictional example, keep the director's individual check-ins unchanged.",
      "I am considering shortening only the weekly group meeting for two weeks and watching for people waiting on decisions.",
      "This is a possible experiment, not a commitment or something already done. Please update the draft."
    )
  ),
  demand = c(
    paste(
      "This is a wholly fictional product example for testing the app.",
      "I think teams of five to twenty engineers using PostgreSQL without a database specialist would pay for a migration-plan review.",
      "Two fictional friends said it sounded useful. I have not offered or sold this yet.",
      "If three teams say yes in interviews, would that establish demand? What should I learn before building?"
    ),
    paste(
      "Still within this fictional example: I do not expect three teams to buy.",
      "I want to learn whether anyone would commit to a paid review of a real upcoming plan.",
      "I have not chosen a price and am not assuming polite interest predicts paying. Please update the draft."
    )
  ),
  measurement = c(
    paste(
      "This is a fictional research example with no real experimental data.",
      "I think longer exposure may change the response, but I am unsure whether I mean a higher average or more variation.",
      "I cannot give a probability interval yet. What would help me decide what to measure?"
    ),
    paste(
      "In this fictional example, I mean more variation between repeated runs, not a higher mean.",
      "I do not yet know the units or the size of the change. Please retain that correction and suggest a small next step."
    )
  )
)
selected <- commandArgs(trailingOnly = TRUE)
if (length(selected)) {
  cases <- cases[selected]
}
stopifnot(length(cases) > 0L, !any(vapply(cases, is.null, logical(1))))
for (name in names(cases)) {
  x <- elicitation_record(
    claim(cases[[name]][[1]], "Fictional example reviewer"),
    paste("Fictional", name)
  )
  state <- suppose:::new_proposal_session(
    function() x,
    general = TRUE,
    model = "meta/muse-spark-1.3-contributor",
    provider = "deputy"
  )
  agent <- suppose_agent()
  cat("\nCASE:", name, "\n")
  for (message in cases[[name]]) {
    id <- state$begin(message)
    agent$set_tools(state$tools(id))
    warnings <- character()
    response <- withCallingHandlers(agent$chat(message), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    })
    stopifnot(deputy::result_is_success(agent$last_run()))
    state$finish(id, response, execution = suppose:::deputy_run_receipt(agent))
    writeLines(
      suppose:::json_data(
        list(
          messages = state$messages,
          proposal = state$pending,
          last_run = suppose:::deputy_run_receipt(agent),
          warnings = warnings
        ),
        pretty = TRUE
      ),
      file.path("artifacts", paste0("quality-live-", name, "-trace.json"))
    )
    cat("\nUSER:", message, "\nASSISTANT:", response, "\n")
    flush.console()
  }
  proposal <- state$pending
  stopifnot(!is.null(proposal), is.null(proposal$candidate))
  # Harness application is only for persistence verification, not semantic approval.
  x <- apply_assistant_proposal(x, proposal, "Fictional example reviewer")
  x <- suppose:::record_conversation(x, state$messages)
  path <- file.path("artifacts", paste0("quality-live-", name, ".json"))
  write_record(x, path, overwrite = TRUE)
  stopifnot(identical(
    suppose:::json_data(x),
    suppose:::json_data(read_record(path))
  ))
  cat("\nSaved and reopened:", path, "\n")
}
