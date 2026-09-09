inquiry_optional_text <- function(x, field) {
  if (is.null(x)) {
    return(NULL)
  }
  if (
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      tolower(trimws(x)) %in%
        c(
          "",
          "null",
          "unknown",
          "unspecified",
          "not specified",
          "not applicable",
          "n/a"
        )
  ) {
    return(NULL)
  }
  check_text(x, field)
  if (
    field %in%
      c("units", "horizon") &&
      grepl(
        "^(unknown|unspecified|not specified|not applicable)\\b",
        tolower(trimws(x))
      )
  ) {
    return(NULL)
  }
  x
}

inquiry_text_array <- function(x, field) {
  if (is.null(x)) {
    return(NULL)
  }
  if (
    is.list(x) &&
      all(vapply(
        x,
        function(value) {
          is.character(value) && length(value) == 1L && !is.na(value)
        },
        logical(1)
      ))
  ) {
    x <- unlist(x, use.names = FALSE) %||% character()
  }
  check_strings(x, field)
  if (any(tolower(trimws(x)) == "null")) {
    abort_suppose(
      "Omit unknown {.arg {field}} rather than supplying the string 'null'.",
      "source"
    )
  }
  x
}

inquiry_stated_units <- function(units, messages) {
  for (message in messages) {
    if (!identical(message$role, "user")) {
      next
    }
    starts <- gregexpr(units, message$text, fixed = TRUE)[[1]]
    for (start in starts[starts > 0L]) {
      end <- start + nchar(units) - 1L
      before <- if (start == 1L) {
        ""
      } else {
        substr(message$text, start - 1L, start - 1L)
      }
      after <- substr(message$text, end + 1L, end + 1L)
      if (!grepl("[[:alpha:]_]", before) && !grepl("[[:alnum:]_]", after)) {
        return(invisible(units))
      }
    }
  }
  abort_suppose(
    "Use units stated by the user, or omit units while they are unknown. Put a suggested measurement in ideas.",
    "source"
  )
}

# Verify quotation boundaries, not the truth or epistemic status of a statement.
# Retain the surrounding message so a reviewer can inspect that status.
inquiry_statement_sources <- function(statements, messages, field) {
  lapply(statements, function(statement) {
    check_quote(statement, messages)
    source_context <- NULL
    for (i in rev(seq_along(messages))) {
      message <- messages[[i]]
      if (!identical(message$role, "user")) {
        next
      }
      positions <- gregexpr(statement, message$text, fixed = TRUE)[[1]]
      if (any(positions > 0L) && is.null(source_context)) {
        source_context <- message$text
      }
      for (start in positions[positions > 0L]) {
        end <- start + nchar(statement) - 1L
        before <- substr(message$text, 1L, start - 1L)
        after <- substr(message$text, end + 1L, nchar(message$text))
        starts <- !nzchar(trimws(before)) ||
          grepl("[.!?][ \t]+$", before) ||
          grepl("\n[ \t]*$", before)
        ends <- !nzchar(trimws(after)) ||
          (grepl("[.!?]$", statement) && grepl("^[ \t\r\n]", after)) ||
          grepl("^[ \t]*\r?\n", after)
        if (starts && ends && !grepl("[?][\"']?$", trimws(statement))) {
          return(list(
            field = field,
            statement = statement,
            message_index = i,
            source_message = message$text
          ))
        }
      }
    }
    abort_suppose(
      c(
        "Keep each {.arg {field}} item as a complete verbatim user statement, including conditions and negation.",
        "i" = "Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.",
        "i" = "Source context: {source_context}"
      ),
      "source"
    )
  })
}
