#' Import measured outcomes with explicit provenance
#'
#' This narrow importer accepts a data frame or CSV file with exactly these
#' columns: `observation_id`, `condition`, `outcome`, `batch`, `specimen`, and
#' `observed_at`. All except `outcome` are nonempty character columns. Times use
#' UTC ISO 8601, for example `2026-09-08T12:00:00Z`, or the explicit string
#' `unknown` when measurement time is not documented. Missing numeric outcomes are
#' retained. Give each actual measurement a stable ID within its source; repeated
#' specimens and batches are allowed, duplicate measurement IDs are not.
#'
#' Exposure is the contributor's declaration relative to the attached claim:
#' `unknown`, `unseen`, `explored`, or `prior` (already used in elicitation).
#' Assessment requires `unseen`; this declaration does not establish prospective
#' testing or independence. No model is fitted by importing observations.
#'
#' Conversion is explicit: `outcome * scale + offset`, into `target_units`.
#' The importer records original rows and conversion parameters. It cannot
#' verify that a user-supplied conversion or source identity is scientifically
#' correct. Simulated predictions have a separate type and are not accepted here.
#' @param data A data frame or path to a CSV file.
#' @param source Stable source identifier, such as a laboratory dataset URI.
#' @param protocol Description or versioned identifier of the measurement method.
#' @param author Person declaring provenance and evidence exposure.
#' @param units Units of the original outcomes.
#' @param role Intended use: `exploration`, `update`, or `assessment`.
#' @param exposure Prior exposure: `unknown`, `unseen`, `explored`, or `prior`.
#' @param target_units Units after conversion, defaulting to `units`.
#' @param scale,offset Explicit linear conversion, defaulting to identity.
#' @return A sealed `suppose_observations` object, including original rows,
#'   converted outcomes, missingness, and potential duplicate-row flags.
#' @export
import_observations <- function(
  data,
  source,
  protocol,
  author,
  units,
  role,
  exposure,
  target_units = units,
  scale = 1,
  offset = 0
) {
  for (arg in c("source", "protocol", "author", "units", "target_units")) {
    check_text(get(arg), arg)
  }
  role <- rlang::arg_match(role, c("exploration", "update", "assessment"))
  exposure <- rlang::arg_match(
    exposure,
    c("unknown", "unseen", "explored", "prior")
  )
  if (role == "assessment" && exposure != "unseen") {
    abort_suppose(
      "Assessment requires an explicit declaration of unseen outcomes. Use exploration for previously examined or uncertain evidence.",
      "exposure"
    )
  }
  if (role == "update" && exposure %in% c("prior", "unknown")) {
    abort_suppose(
      "Updating requires known evidence exposure and cannot reuse observations already incorporated into the prior.",
      "exposure"
    )
  }
  check_number(scale, "scale")
  check_number(offset, "offset")
  if (scale == 0) {
    abort_suppose("Conversion scale cannot be zero.")
  }
  file_hash <- NULL
  if (is.character(data) && length(data) == 1L && !is.na(data)) {
    path <- data
    if (!fs::file_exists(path)) {
      abort_suppose("Observation CSV not found: {.path {path}}.", "io")
    }
    file_hash <- digest::digest(file = path, algo = "sha256")
    data <- tryCatch(
      utils::read.csv(
        path,
        colClasses = "character",
        check.names = FALSE,
        na.strings = "",
        strip.white = FALSE
      ),
      error = function(e) {
        abort_suppose("Could not read observation CSV.", "io", parent = e)
      }
    )
    if ("outcome" %in% names(data)) {
      raw_outcome <- data$outcome
      data$outcome <- suppressWarnings(as.numeric(raw_outcome))
      if (any(is.na(data$outcome) & !is.na(raw_outcome))) {
        abort_suppose(
          "CSV outcomes must be numeric or blank for missing values."
        )
      }
    }
  }
  columns <- c(
    "observation_id",
    "condition",
    "outcome",
    "batch",
    "specimen",
    "observed_at"
  )
  if (
    !is.data.frame(data) ||
      anyDuplicated(names(data)) ||
      !setequal(names(data), columns) ||
      nrow(data) < 1L ||
      nrow(data) > 100000L
  ) {
    abort_suppose(
      "Supply 1 to 100000 rows with exactly: observation_id, condition, outcome, batch, specimen, observed_at."
    )
  }
  for (field in setdiff(columns, "outcome")) {
    check_strings(data[[field]], field)
  }
  if (
    !is.numeric(data$outcome) ||
      any(is.infinite(data$outcome)) ||
      any(is.nan(data$outcome))
  ) {
    abort_suppose(
      "Outcomes must be finite numbers or NA for missing measurements."
    )
  }
  if (anyDuplicated(data$observation_id)) {
    abort_suppose(
      "Observation IDs must be unique within a source. Retain distinct IDs for actual replicate measurements.",
      "duplicate"
    )
  }
  valid_time <- grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$",
    data$observed_at
  )
  parsed <- as.POSIXct(
    data$observed_at,
    format = "%Y-%m-%dT%H:%M:%OSZ",
    tz = "UTC"
  )
  unknown_time <- data$observed_at == "unknown"
  invalid_time <- !valid_time |
    is.na(parsed) |
    format(parsed, "%Y-%m-%dT%H:%M:%S", tz = "UTC") !=
      substr(data$observed_at, 1, 19)
  if (any(!unknown_time & invalid_time)) {
    abort_suppose(
      "Observation times must be valid UTC timestamps such as 2026-09-08T12:00:00Z, or unknown when not documented."
    )
  }
  converted <- data$outcome * scale + offset
  if (any(!is.finite(converted) & !is.na(data$outcome))) {
    abort_suppose("Conversion produced a non-finite outcome.")
  }
  rows <- lapply(seq_len(nrow(data)), function(i) {
    row <- as.list(data[i, columns, drop = FALSE])
    if (is.na(row$outcome)) {
      row["outcome"] <- list(NULL)
    }
    row["converted"] <- list(if (is.na(converted[i])) NULL else converted[i])
    row
  })
  signatures <- vapply(
    rows,
    function(row) object_id(row[setdiff(names(row), "observation_id")]),
    character(1)
  )
  seal(
    list(
      source = source,
      protocol = protocol,
      author = author,
      units = units,
      target_units = target_units,
      role = role,
      exposure = exposure,
      conversion = list(scale = scale, offset = offset),
      file_hash = file_hash,
      rows = rows,
      missing_ids = data$observation_id[is.na(data$outcome)],
      repeated_ids = data$observation_id[
        duplicated(signatures) | duplicated(signatures, fromLast = TRUE)
      ],
      created_at = now_utc()
    ),
    "suppose_observations"
  )
}

#' Attach measured observations to the current claim revision
#'
#' Retains the exact claim, record-entry index, and candidate reference with the
#' observations. Existing revisions and acceptance are unchanged. Reimporting
#' the same source/measurement ID is rejected, even with a different role or
#' conversion. New claim revisions do not relabel the earlier evidence.
#' @param x A local record.
#' @param observations An object from [import_observations()].
#' @param reason Why these observations belong with this claim revision.
#' @return A schema-4 record with a separate observations collection.
#' @export
record_observations <- function(x, observations, reason) {
  validate_record(x)
  validate_observations(observations)
  check_text(reason, "reason")
  index <- length(x$revisions)
  e <- x$revisions[[index]]
  if (
    !is.null(e$claim$units) &&
      !identical(e$claim$units, observations$target_units)
  ) {
    abort_suppose(
      "Converted observation units must match the claim units exactly. Specify the conversion explicitly before attaching.",
      "units"
    )
  }
  attachment <- seal(
    list(
      data = observations,
      claim_id = e$claim$id,
      revision = index,
      prior_id = e$candidate$id,
      reason = reason,
      created_at = now_utc()
    ),
    "suppose_evidence"
  )
  x$observations <- c(x$observations, list(attachment))
  x$schema_version <- max(x$schema_version, 4L)
  validate_record(x)
  x
}

validate_observations <- function(x) {
  check_seal(x, "suppose_observations")
  if (!is.list(x$rows) || !length(x$rows)) {
    abort_suppose("Observation rows are missing.", "record")
  }
  for (row in x$rows) {
    if (
      !is.list(row) ||
        !setequal(
          names(row),
          c(
            "observation_id",
            "condition",
            "outcome",
            "batch",
            "specimen",
            "observed_at",
            "converted"
          )
        )
    ) {
      abort_suppose("Malformed observation row.", "record")
    }
  }
  data <- do.call(
    rbind,
    lapply(x$rows, function(row) {
      row$converted <- NULL
      if (is.null(row$outcome)) {
        row$outcome <- NA_real_
      }
      as.data.frame(row, stringsAsFactors = FALSE)
    })
  )
  rebuilt <- import_observations(
    data,
    x$source,
    x$protocol,
    x$author,
    x$units,
    x$role,
    x$exposure,
    x$target_units,
    x$conversion$scale,
    x$conversion$offset
  )
  for (field in c("rows", "missing_ids", "repeated_ids")) {
    if (!identical(json_data(x[[field]]), json_data(rebuilt[[field]]))) {
      abort_suppose(
        "Observation values and declared conversion disagree.",
        "record"
      )
    }
  }
  invisible(x)
}

validate_evidence <- function(x) {
  keys <- character()
  for (attachment in x$observations) {
    check_seal(attachment, "suppose_evidence")
    validate_observations(attachment$data)
    check_count(
      attachment$revision,
      "evidence revision",
      upper = length(x$revisions)
    )
    e <- x$revisions[[attachment$revision]]
    if (
      !identical(e$claim$id, attachment$claim_id) ||
        !identical(e$candidate$id, attachment$prior_id)
    ) {
      abort_suppose(
        "Observations reference a different claim or candidate.",
        "revision"
      )
    }
    if (
      !is.null(e$claim$units) &&
        !identical(e$claim$units, attachment$data$target_units)
    ) {
      abort_suppose(
        "Observation units disagree with the referenced claim.",
        "units"
      )
    }
    check_text(attachment$reason, "evidence reason")
    added <- vapply(
      attachment$data$rows,
      function(row) {
        object_id(list(
          source = attachment$data$source,
          observation_id = row$observation_id
        ))
      },
      character(1)
    )
    if (any(added %in% keys)) {
      abort_suppose(
        "These source/observation IDs are already attached. Reusing them under a new role or conversion would count the same information twice.",
        "duplicate"
      )
    }
    keys <- c(keys, added)
  }
  invisible(x)
}

#' @export
print.suppose_observations <- function(x, ...) {
  validate_observations(x)
  cli::cli_h2("Measured observations")
  cli::cli_text(
    "{length(x$rows)} rows from {x$source}; {length(x$missing_ids)} missing outcomes."
  )
  cli::cli_text(
    "Use: {x$role}. Prior exposure: {x$exposure}. Units: {x$target_units}."
  )
  cli::cli_text(
    "{length(x$repeated_ids)} rows have identical measurement fields; retained for review."
  )
  invisible(x)
}

observation_inventory <- function(x) {
  lapply(x$observations, function(a) {
    list(
      revision = a$revision,
      claim_id = a$claim_id,
      source = a$data$source,
      protocol = a$data$protocol,
      role = a$data$role,
      exposure = a$data$exposure,
      rows = length(a$data$rows),
      missing = length(a$data$missing_ids),
      rows_flagged_for_duplicate_review = length(a$data$repeated_ids),
      units = a$data$target_units,
      note = "This collection retains measurements. See the separate updates collection for fitted results; importing alone performs no fit or independent test. Repeated-field flags require review and do not prove accidental copies."
    )
  })
}
