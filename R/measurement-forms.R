measurement_form_defaults <- function(record) {
  list(
    csv_text = "",
    id_column = "observation_id",
    outcome_column = "outcome",
    predictor_columns = character(),
    predictor_units = character(),
    condition_column = "",
    batch_column = "",
    specimen_column = "",
    observed_at_column = "",
    observed_at = "unknown",
    collection_note = "",
    source = "",
    protocol = "",
    author = "You",
    units = utils::tail(record$revisions, 1)[[1]]$claim$units %||% "",
    role = "exploration",
    exposure = "unknown"
  )
}

measurement_table <- function(text) {
  check_text(text, "csv_text")
  if (nchar(text, type = "bytes") > 500000L) {
    abort_suppose("Use at most 500 KB of pasted CSV for this import.")
  }
  connection <- textConnection(text)
  on.exit(close(connection), add = TRUE)
  fields <- utils::count.fields(
    connection,
    sep = ",",
    quote = "\"",
    comment.char = ""
  )
  fields <- fields[!is.na(fields)]
  if (!length(fields) || length(unique(fields)) != 1L) {
    abort_suppose(
      "Each CSV row must have the same number of fields as the header."
    )
  }
  d <- tryCatch(
    utils::read.csv(
      text = text,
      colClasses = "character",
      check.names = FALSE,
      na.strings = "",
      strip.white = TRUE
    ),
    error = function(e) abort_suppose("Could not parse the pasted CSV table.")
  )
  if (
    !nrow(d) ||
      nrow(d) > 500L ||
      anyDuplicated(names(d)) ||
      !all(nzchar(names(d)))
  ) {
    abort_suppose("Supply 1 to 500 rows with unique, nonempty column names.")
  }
  d
}

measurement_form_preview <- function(record, values, form_draft = NULL) {
  v <- workbench_form_values(record, "import", values)
  d <- measurement_table(v$csv_text)
  selected <- c(
    v$id_column,
    v$outcome_column,
    v$predictor_columns,
    v$condition_column,
    v$batch_column,
    v$specimen_column,
    v$observed_at_column
  )
  if (!all(selected[nzchar(selected)] %in% names(d))) {
    abort_suppose("Choose mapped columns that exist in the table.")
  }
  if (
    !nzchar(v$id_column) ||
      !nzchar(v$outcome_column) ||
      anyDuplicated(c(v$id_column, v$outcome_column, v$predictor_columns))
  ) {
    abort_suppose("Map distinct ID, outcome and predictor columns.")
  }
  numeric_column <- function(name) {
    raw <- d[[name]]
    out <- suppressWarnings(as.numeric(raw))
    if (any(!is.na(raw) & is.na(out)) || any(is.infinite(out))) {
      abort_suppose(
        "Column {.val {name}} contains nonnumeric or infinite measurements."
      )
    }
    out
  }
  mapped <- function(name, default = "unknown") {
    if (nzchar(name)) d[[name]] else rep(default, nrow(d))
  }
  outcomes <- data.frame(
    observation_id = d[[v$id_column]],
    condition = mapped(v$condition_column),
    outcome = numeric_column(v$outcome_column),
    batch = mapped(v$batch_column),
    specimen = mapped(v$specimen_column),
    observed_at = mapped(v$observed_at_column, v$observed_at),
    stringsAsFactors = FALSE
  )
  observations <- import_observations(
    outcomes,
    v$source,
    v$protocol,
    v$author,
    v$units,
    v$role,
    v$exposure
  )
  if (!is.null(form_draft)) {
    check_seal(form_draft, "suppose_form_draft")
    if (
      !identical(form_draft$form, "import") ||
        !identical(form_draft$base_id, proposal_basis_id(record))
    ) {
      abort_suppose(
        "This table draft belongs to another record revision.",
        "stale"
      )
    }
  }
  out <- record_observations(record, observations, "Reviewed table import")
  index <- length(out$observations)
  evidence <- out$observations[[index]]
  evidence$id <- NULL
  evidence$table_import <- list(
    values = v,
    form_draft = form_draft,
    csv_sha256 = digest::digest(v$csv_text, algo = "sha256", serialize = FALSE)
  )
  out$observations[[index]] <- seal(evidence, "suppose_evidence")
  predictors <- NULL
  if (length(v$predictor_columns)) {
    if (length(v$predictor_units) != length(v$predictor_columns)) {
      abort_suppose(
        "Supply one unit per predictor in the selected column order."
      )
    }
    pd <- data.frame(
      observation_id = d[[v$id_column]],
      stringsAsFactors = FALSE
    )
    for (name in v$predictor_columns) {
      pd[[name]] <- numeric_column(name)
    }
    predictors <- regression_predictors(
      out,
      utils::tail(out$observations, 1)[[1]]$id,
      pd,
      stats::setNames(v$predictor_units, v$predictor_columns),
      v$source,
      v$author
    )
    out <- record_predictors(out, predictors)
  }
  list(values = v, data = observations, predictors = predictors, record = out)
}

measurement_source_check <- function(csv_text, messages) {
  # Some chat composers normalize pasted line breaks. Permit that formatting
  # change only; preserve every non-newline character of the supplied table.
  normalized <- gsub("[\r\n]", "", csv_text)
  user <- Filter(function(m) identical(m$role, "user"), messages)
  if (
    !nzchar(normalized) ||
      !any(vapply(
        user,
        function(m) {
          grepl(normalized, gsub("[\r\n]", "", m$text), fixed = TRUE)
        },
        logical(1)
      ))
  ) {
    abort_suppose(
      "Copy the user's CSV exactly; only line-break normalization is allowed.",
      "source"
    )
  }
}

measurement_form_tools <- function(id, guard, state, receipt) {
  list(ellmer::tool(
    function(
      source_quote,
      reason,
      csv_text = NULL,
      id_column = NULL,
      outcome_column = NULL,
      predictor_columns = NULL,
      predictor_units = NULL,
      source = NULL,
      protocol = NULL,
      units = NULL,
      author = NULL,
      role = NULL,
      exposure = NULL,
      batch_column = NULL,
      specimen_column = NULL,
      condition_column = NULL,
      observed_at_column = NULL,
      observed_at = NULL,
      collection_note = NULL
    ) {
      guard(id)
      supplied <- as.list(environment())
      supplied[c("source_quote", "reason")] <- NULL
      values <- Filter(Negate(is.null), supplied)
      if (!is.null(csv_text)) {
        measurement_source_check(csv_text, state$messages)
      }
      result <- stage_workbench_form(
        state,
        "import",
        values,
        source_quote,
        reason
      )
      receipt(
        "draft_measurements",
        list(values = values, source_quote = source_quote, reason = reason),
        result
      )
    },
    paste(
      "Prepare one human-reviewed import of a CSV table pasted by the user.",
      "Copy the CSV exactly (line-break normalization is allowed); map separate ID, outcome and up to two numeric predictors.",
      "Supply predictor units in the same order. Outcomes are not predictors.",
      "Use stated provenance and exposure; keep unknown batch/specimen/time as unknown, never infer independence.",
      "A date without a time belongs in collection_note, not an invented UTC timestamp.",
      "Use role update only when requested for fitting and exposure is explored or unseen; exploration/unknown is the default.",
      "Omitted fields preserve an existing draft. The Import a table panel opens with a preview.",
      "The person must click Attach reviewed table; the tool neither attaches evidence nor fits models.",
      "Do not create another interpretation draft merely to import data."
    ),
    arguments = list(
      source_quote = ellmer::type_string(
        "Exact user request or source message."
      ),
      reason = ellmer::type_string(
        "Why these measurements belong to the inquiry."
      ),
      csv_text = ellmer::type_string(
        "Exact CSV from the user's message.",
        required = FALSE
      ),
      id_column = ellmer::type_string(required = FALSE),
      outcome_column = ellmer::type_string(required = FALSE),
      predictor_columns = ellmer::type_array(
        ellmer::type_string(),
        required = FALSE
      ),
      predictor_units = ellmer::type_array(
        ellmer::type_string(),
        required = FALSE
      ),
      source = ellmer::type_string(
        "Stable source label, explicitly label fictional/synthetic data.",
        required = FALSE
      ),
      protocol = ellmer::type_string(
        "Stated collection/measurement protocol; do not invent missing details.",
        required = FALSE
      ),
      units = ellmer::type_string(
        "Outcome units stated by the user.",
        required = FALSE
      ),
      author = ellmer::type_string(required = FALSE),
      role = ellmer::type_enum(
        c("exploration", "update", "assessment"),
        required = FALSE
      ),
      exposure = ellmer::type_enum(
        c("unknown", "unseen", "explored", "prior"),
        required = FALSE
      ),
      batch_column = ellmer::type_string(required = FALSE),
      specimen_column = ellmer::type_string(required = FALSE),
      condition_column = ellmer::type_string(required = FALSE),
      observed_at_column = ellmer::type_string(required = FALSE),
      observed_at = ellmer::type_string(
        "Common exact UTC timestamp or unknown.",
        required = FALSE
      ),
      collection_note = ellmer::type_string(
        "Stated date or other collection detail at its original precision.",
        required = FALSE
      )
    ),
    name = "draft_measurements"
  ))
}
