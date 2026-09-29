await_r <- function(p) {
  done <- FALSE
  value <- NULL
  promises::then(
    p,
    function(x) {
      value <<- x
      done <<- TRUE
    },
    function(e) {
      value <<- e
      done <<- TRUE
    }
  )
  deadline <- Sys.time() + 10
  while (!done && Sys.time() < deadline) {
    later::run_now(0.05)
  }
  if (!done) {
    stop("R worker did not settle")
  }
  if (inherits(value, "error")) {
    stop(value)
  }
  value
}
r_text <- function(x) {
  paste(
    vapply(
      Filter(function(v) inherits(v, "ellmer::ContentText"), x@value),
      function(v) v@text,
      character(1)
    ),
    collapse = "\n"
  )
}

fixture_r_agent <- function() {
  skip_if_not_installed("deputy")
  skip_if_not_installed("ellmer")
  suppose_agent(
    ellmer::chat_openai_compatible(
      base_url = "http://127.0.0.1:3893/v1",
      model = "fixture",
      credentials = function() "fixture"
    ),
    bundles = "r",
    working_dir = tempdir()
  )
}
