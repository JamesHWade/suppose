# Runtime tools belong to the receiving agent. Deputy transfers conversational
# state and integrity-checked result archives through its public session API.
transfer_inquiry_session <- function(from, to) {
  path <- tempfile("suppose-session-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  from$save_session(path)
  to$load_session(path)
  invisible(to)
}

inquiry_context_summary <- function(request) {
  x <- request$base
  e <- utils::tail(x$revisions, 1)[[1]]
  compact <- function(z) {
    text <- as.character(json_data(plain(z)))
    if (nchar(text) <= 5000L) {
      z
    } else {
      list(
        preview = substr(text, 1L, 4500L),
        truncated = TRUE,
        details = "Use read_inquiry for the full current record."
      )
    }
  }
  list(
    record_id = x$record_id,
    revision = length(x$revisions),
    claim = compact(e$claim),
    applied_review = if (is.null(e$acceptance)) {
      "unreviewed"
    } else {
      e$acceptance$kind %||% "numerical candidate"
    },
    pending_interpretation = compact(request$changes$claim),
    pending_status = "Suggestions are not applied revisions or reviewed commitments.",
    observations = lapply(utils::tail(x$observations, 5), function(a) {
      list(
        id = a$id,
        source = a$data$source,
        rows = length(a$data$rows),
        role = a$data$role,
        exposure = a$data$exposure,
        revision = a$revision,
        units = a$data$target_units
      )
    }),
    predictor_datasets = lapply(utils::tail(x$predictors, 5), function(d) {
      list(
        id = d$id,
        evidence_id = d$evidence_id,
        units = d$units,
        rows = length(d$rows),
        revision = d$revision
      )
    }),
    retained_counts = vapply(
      stats::setNames(
        c(
          "observations",
          "predictors",
          "updates",
          "commitments",
          "assessments",
          "sensitivities",
          "model_extensions",
          "regressions"
        ),
        c(
          "observations",
          "predictors",
          "updates",
          "commitments",
          "assessments",
          "sensitivities",
          "model_extensions",
          "regressions"
        )
      ),
      function(name) length(x[[name]]),
      integer(1)
    ),
    summary_scope = "Latest five evidence and predictor attachments; latest regression. read_inquiry supplies older details.",
    latest_regression = compact(utils::tail(regression_inventory(x), 1)),
    latest_research_design = compact(utils::tail(
      research_design_inventory(x),
      1
    )),
    workbench_forms = lapply(request$form_state, function(f) {
      if (is.null(f)) {
        return(NULL)
      }
      values <- f$values
      if (!is.null(values$csv_text)) {
        values$csv_text <- "Table already staged; do not resend unless correcting it."
      }
      compact(list(values = values, version = f$version))
    }),
    methods = c(
      "Unknown-noise regression supports one or two numeric predictors; no known batch SD is required.",
      "draft_measurements prepares pasted CSV outcomes and predictors for one human-reviewed import.",
      "draft_regression prepares priors only; the human fits and retains in Fit and compare models.",
      "draft_research_design prepares exact BED planning reviews from a retained chosen regression; /design does not freeze or execute a test.",
      "read_inquiry retrieves details omitted here; no routine read is necessary."
    )
  )
}

inquiry_context_prompt <- function(prompt, summary) {
  # JSON is one line, so user text cannot terminate this delimited section.
  prompt <- gsub(
    "\n<suppose-current-state>\n[^\n]*\n</suppose-current-state>\n",
    "",
    prompt,
    perl = TRUE
  )
  paste0(
    prompt,
    "\n<suppose-current-state>\n",
    as.character(jsonlite::toJSON(
      plain(summary),
      auto_unbox = TRUE,
      null = "null",
      digits = NA
    )),
    "\n</suppose-current-state>\n"
  )
}

# Validation failures need a useful short message, not captured Shiny closures
# or rlang stack frames that force a second tool call just to read an error.
compact_inquiry_tool <- function(tool) {
  original <- tool
  fun <- function() {
    args <- as.list(environment())
    tryCatch(do.call(original, args), error = function(e) {
      stop(structure(
        list(message = cli::ansi_strip(conditionMessage(e)), call = NULL),
        class = unique(c(
          setdiff(class(e), "rlang_error"),
          "error",
          "condition"
        ))
      ))
    })
  }
  formals(fun) <- formals(original)
  ellmer::tool(
    fun,
    tool@description,
    arguments = tool@arguments@properties,
    name = tool@name,
    convert = tool@convert
  )
}
