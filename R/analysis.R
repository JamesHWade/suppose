# An execution journal does not change the scientific basis of a proposal.
proposal_basis_id <- function(x) {
  x$analyses <- NULL
  if (x$schema_version == 6L) {
    x$schema_version <- if (!is.null(x$updates)) {
      5L
    } else if (!is.null(x$observations)) {
      4L
    } else if (!is.null(x$conversation)) {
      3L
    } else if (
      any(vapply(x$revisions, function(e) !is.null(e$assistance), logical(1)))
    ) {
      2L
    } else {
      1L
    }
  }
  object_id(x)
}

#' Retain an R execution with its scientific context
#'
#' Stores code, ordered console output and static PNG plots as plain data.
#' The context identifies available record inputs; it does not certify that
#' generated code used them correctly. Live R objects are never serialized.
#' @param x An elicitation record.
#' @param execution Deputy's version 1 `extra$deputy_r` execution record.
#'   Fields that version does not define are not stored.
#' @param source_prompt User message that initiated the response.
#' @param model Model identifier or a descriptive name for a manual analysis.
#' @param request_id Host response identifier.
#' @return A record with an appended sealed analysis, leaving revisions unchanged.
#' @export
record_analysis <- function(x, execution, source_prompt, model, request_id) {
  validate_record(x)
  for (nm in c("source_prompt", "model", "request_id")) {
    check_text(get(nm), nm)
  }
  if (!is.list(execution) || !identical(execution$schema_version, 1L)) {
    abort_suppose("Expected a version 1 Deputy execution record.", "analysis")
  }
  fields <- c(
    "schema_version",
    "code",
    "session_id",
    "execution_id",
    "generation",
    "fresh",
    "reset_reason",
    "outcome",
    "segments"
  )
  absent <- setdiff(fields, names(execution))
  if (length(absent)) {
    abort_suppose(
      "Malformed execution record: missing field{?s} {.field {absent}}.",
      "analysis"
    )
  }
  # Deputy may add fields to its version 1 record. Keep only the fields that
  # version defines, in this order, so every sealed analysis has one shape.
  execution <- execution[fields]
  for (nm in c("code", "session_id", "execution_id", "outcome")) {
    check_text(execution[[nm]], nm)
  }
  execution$segments <- lapply(execution$segments, function(s) {
    if (identical(s$type, "plot")) {
      if (!is.raw(s$data)) {
        abort_suppose("Expected raw PNG plot data.", "analysis")
      }
      list(
        type = "plot",
        media_type = "image/png",
        data = gsub("[\r\n]", "", jsonlite::base64_enc(s$data))
      )
    } else {
      check_text(s$type, "output type")
      if (!is.character(s$text) || length(s$text) != 1L || is.na(s$text)) {
        abort_suppose("Invalid console output.", "analysis")
      }
      list(type = s$type, text = s$text)
    }
  })
  revision <- length(x$revisions)
  entry <- x$revisions[[revision]]
  a <- seal(
    list(
      revision = revision,
      claim_id = entry$claim$id,
      prior_id = entry$candidate$id,
      observation_ids = vapply(
        x$observations,
        function(a) a$data$id,
        character(1)
      ),
      runtime_version = as.character(utils::packageVersion("deputy")),
      source_prompt = source_prompt,
      model = model,
      request_id = request_id,
      execution = execution,
      created_at = now_utc()
    ),
    "suppose_analysis"
  )
  duplicate <- vapply(
    x$analyses,
    function(old) {
      identical(old$execution$session_id, execution$session_id) &&
        identical(old$execution$execution_id, execution$execution_id)
    },
    logical(1)
  )
  if (any(duplicate)) {
    return(x)
  }
  x$analyses <- c(x$analyses, list(a))
  x$schema_version <- max(x$schema_version, 6L)
  validate_record(x)
  x
}

validate_analyses <- function(x) {
  if (is.null(x$analyses)) {
    return(invisible(x))
  }
  if (x$schema_version < 6 || !is.list(x$analyses)) {
    abort_suppose("Invalid analysis collection.", "record")
  }
  for (a in x$analyses) {
    check_seal(a, "suppose_analysis")
    check_count(a$revision, "analysis revision", 1, length(x$revisions))
    e <- x$revisions[[a$revision]]
    ids <- vapply(x$observations, function(o) o$data$id, character(1))
    if (
      !identical(a$claim_id, e$claim$id) ||
        !identical(a$prior_id, e$candidate$id) ||
        !all(a$observation_ids %in% ids)
    ) {
      abort_suppose(
        "Analysis references unavailable scientific inputs.",
        "record"
      )
    }
  }
  invisible(x)
}

analysis_inventory_ui <- function(x) {
  if (!length(x$analyses)) {
    return(shiny::tags$p(
      "R code and results will be retained here, independently of model context compaction."
    ))
  }
  lapply(x$analyses, function(a) {
    e <- a$execution
    shiny::tags$details(
      shiny::tags$summary(paste("Revision", a$revision, "\u2014", e$outcome)),
      inquiry_field("Source request", a$source_prompt),
      inquiry_field("Model", a$model),
      inquiry_field(
        "Execution",
        paste(e$session_id, e$execution_id, "generation", e$generation)
      ),
      shiny::tags$p(
        "Context references identify available inputs and assumptions; review the code to check how they were used. Reopened analyses are saved results; live variables start fresh."
      ),
      inquiry_field("Prior", a$prior_id),
      inquiry_field("Measurements", a$observation_ids),
      shiny::tags$pre(shiny::tags$code(e$code)),
      lapply(e$segments, function(s) {
        if (identical(s$type, "plot")) {
          shiny::tags$img(
            src = paste0("data:image/png;base64,", s$data),
            alt = "Saved plot from the displayed R code.",
            style = "max-width:100%;height:auto;"
          )
        } else {
          shiny::tags$pre(paste0(s$type, ": ", s$text))
        }
      })
    )
  })
}
