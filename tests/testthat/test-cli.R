test_that("the packaged CLI uses the same computations and clean JSON output", {
  script <- system.file("exec", "suppose", package = "suppose", mustWork = TRUE)
  path <- withr::local_tempfile(fileext = ".json")
  Rapp::run(script, c("demo", path, "--seed", "47"))
  out <- capture.output(Rapp::run(script, c("inspect", path, "--json")))
  expect_equal(jsonlite::fromJSON(paste(out, collapse = "\n"))$revisions, 3)
  out <- capture.output(Rapp::run(
    script,
    c("predict", path, "--seed", "7", "--n", "20")
  ))
  result <- jsonlite::fromJSON(paste(out, collapse = "\n"))
  record <- read_record(path)
  reference <- predict_prior(record$revisions[[3]]$candidate, seed = 7, n = 20)
  expect_equal(result$draws, reference$draws)
  expect_equal(result$summary, reference$summary)
  err <- tryCatch(Rapp::run(script, c("predict", path)), error = identity)
  expect_s3_class(err, "suppose_input")
})

test_that("the CLI exposes qualitative meaning and refuses invented predictions", {
  script <- system.file("exec", "suppose", package = "suppose", mustWork = TRUE)
  words <- "If three teams say yes, would that establish demand?"
  x <- elicitation_record(claim(
    words,
    "Reviewer",
    unresolved = "What would count as a paid commitment?"
  ))
  x <- accept_interpretation(
    x,
    "Reviewer",
    "Preserves the conditional question",
    "No one pays"
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_record(x, path)
  out <- capture.output(Rapp::run(script, c("inspect", path, "--json")))
  result <- jsonlite::fromJSON(paste(out, collapse = "\n"))
  expect_identical(result$interpretation$wording, words)
  expect_identical(
    result$interpretation$unresolved,
    "What would count as a paid commitment?"
  )
  expect_identical(result$review$kind, "interpretation")
  expect_length(result$latest, 0L)
  expect_snapshot(print(x))
  expect_snapshot(
    error = TRUE,
    Rapp::run(script, c("predict", path, "--seed", "47"))
  )
})

test_that("CLI measurements retain provenance and refuse double import", {
  script <- system.file("exec", "suppose", package = "suppose", mustWork = TRUE)
  input <- withr::local_tempfile(fileext = ".json")
  output <- withr::local_tempfile(fileext = ".json")
  csv <- withr::local_tempfile(fileext = ".csv")
  write_record(
    elicitation_record(claim("Voltage differs", "Ada", units = "mV")),
    input
  )
  utils::write.csv(
    data.frame(
      observation_id = "m1",
      condition = "warm",
      outcome = 10,
      batch = "b1",
      specimen = "s1",
      observed_at = "2026-09-08T12:00:00Z"
    ),
    csv,
    row.names = FALSE
  )
  args <- c(
    "observe",
    input,
    csv,
    output,
    "lab:1",
    "v1",
    "Ada",
    "mV",
    "Inspect"
  )
  Rapp::run(script, args)
  saved <- read_record(output)
  expect_equal(saved$observations[[1]]$data$rows[[1]]$outcome, 10)
  expect_equal(saved$observations[[1]]$data$exposure, "unknown")
  expect_equal(length(saved$revisions), 1L)
  args[2] <- output
  args[4] <- withr::local_tempfile(fileext = ".json")
  expect_snapshot(error = TRUE, Rapp::run(script, args))
})
