abort_suppose <- function(
  message,
  class = "input",
  ...,
  call = rlang::caller_env()
) {
  cli::cli_abort(
    message,
    class = c(paste0("suppose_", class), "suppose_error"),
    ...,
    call = call,
    .envir = call
  )
}
check_text <- function(x, arg, optional = FALSE) {
  if (optional && is.null(x)) {
    return(invisible(x))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    abort_suppose("{.arg {arg}} must be one nonempty string.", arg = arg)
  }
  invisible(x)
}
check_strings <- function(x, arg) {
  if (!is.character(x) || anyNA(x) || any(!nzchar(trimws(x)))) {
    abort_suppose(
      "{.arg {arg}} must be a character vector without missing or empty values.",
      arg = arg
    )
  }
}
check_number <- function(x, arg, lower = -Inf, upper = Inf) {
  if (
    !is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lower || x > upper
  ) {
    abort_suppose(
      "{.arg {arg}} must be one finite number between {lower} and {upper}.",
      arg = arg
    )
  }
}
check_count <- function(x, arg, lower = 1, upper = 1e6) {
  check_number(x, arg, lower, upper)
  if (x != floor(x)) {
    abort_suppose("{.arg {arg}} must be a whole number.", arg = arg)
  }
}
now_utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
plain <- function(x) {
  if (is.list(x)) {
    return(lapply(unclass(x), plain))
  }
  x
}
json_data <- function(x, pretty = FALSE) {
  jsonlite::toJSON(
    plain(x),
    auto_unbox = FALSE,
    null = "null",
    digits = NA,
    pretty = pretty,
    na = "null"
  )
}
object_id <- function(x) {
  digest::digest(json_data(x), algo = "sha256", serialize = FALSE)
}
seal <- function(x, class) {
  x$type <- class
  x$id <- object_id(x)
  structure(x, class = c(class, "list"))
}
check_seal <- function(x, class) {
  if (
    !is.list(x) ||
      !identical(x$type, class) ||
      !is.character(x$id) ||
      length(x$id) != 1L
  ) {
    abort_suppose("Expected a valid {.cls {class}} record.", "record")
  }
  id <- x$id
  x$id <- NULL
  if (!identical(id, object_id(x))) {
    abort_suppose(
      "The {class} record has changed outside its revision API.",
      "integrity"
    )
  }
  invisible(x)
}
